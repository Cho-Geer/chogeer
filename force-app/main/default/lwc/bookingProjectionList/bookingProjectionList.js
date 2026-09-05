/**
 * S-11 予約投影リスト（P0-4・F-23/F-24/F-26・BD-05 screen-items.md S-11-01〜10・MSG-01〜06）
 *
 * 設計値（BD-05 §3.3 S-11）：
 * - 一覧は getProjections（cacheable wire）・状態は canonical 値原样表示（CD-03/CD-07）
 * - 行内キャンセルは S-11-06：PENDING/CONFIRMED のみ活性・CANCELLED/COMPLETED は非活性（MSG-04）
 * - 確認ダイアログ（拍板 5）→ submitCancel（bookingExternalId・expectedVersion）→
 *   MSG-06 表示→ pollCommandStatus（非 cacheable・拍板 2b）を 3 秒間隔で最長 60 秒ポーリング
 * - 終態：SUCCEEDED→refreshApex（S-11-05 更新 CANCELLED）／CONFLICT・FAILED→MSG-05
 * - S-11-07 処理状態（canonical 原样）・S-11-08 再読み込み（refreshApex＋ポーリング中は即時 1 回）
 * - 空一覧→MSG-01・wire/poll 通信エラー→MSG-02・submitCancel 異常→Apex message 優先、無ければ MSG-03
 * - SyncStatus__c は表示しない（BD-05 に表示項目なし）・CurrentVersion__c／BookingExternalId__c は内部保持
 */
import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getProjections from "@salesforce/apex/BookingSiteController.getProjections";
import submitCancel from "@salesforce/apex/BookingSiteController.submitCancel";
import pollCommandStatus from "@salesforce/apex/BookingSiteController.pollCommandStatus";

const POLL_INTERVAL_MS = 3000; // S-11-07 ポーリング間隔（拍板 3）
const POLL_MAX_MS = 60000; // 最長 60 秒で自動停止（拍板 3）

// canonical 値（CD-03/CD-07/CD-08・設計値のまま）
const STATUS_PENDING = "PENDING";
const STATUS_CONFIRMED = "CONFIRMED";
const STATUS_SUCCEEDED = "SUCCEEDED";
const STATUS_CONFLICT = "CONFLICT";
const STATUS_FAILED = "FAILED";

// 文言＝設計値原样（screen-items.md §3.1 MSG-01〜06）
const MSG_01 = "表示できる予約データがありません";
const MSG_02 = "データの取得に失敗しました。再読み込みしてください";
const MSG_03 = "この操作は許可されていません";
const MSG_04 = "この予約はキャンセルできません";
const MSG_05 =
  "キャンセル処理が完了しませんでした（状態：{status}）。詳細は管理者に確認してください";
const MSG_06 =
  "キャンセルを受け付けました（受付番号：{commandId}）。状態が更新され次第表示されます";

// 確認ダイアログ文言（MSG 表外・拍板 5 の実装値）
const CONFIRM_CANCEL_MESSAGE = "この予約をキャンセルしますか？";

const COLUMNS = [
  { label: "予約番号", fieldName: "AppointmentNumber__c" }, // S-11-01
  { label: "予約日付", fieldName: "dateLabel" }, // S-11-02（YYYY-MM-DD）
  { label: "時間枠", fieldName: "TimeSlot__c" }, // S-11-03
  { label: "サービス名", fieldName: "ServiceName__c" }, // S-11-04
  { label: "状態", fieldName: "Status__c" }, // S-11-05（canonical 原样）
  {
    label: "操作",
    fieldName: "cancelAction",
    type: "button", // S-11-06
    typeAttributes: {
      label: "キャンセル",
      name: "cancel",
      title: { fieldName: "cancelTitle" },
      disabled: { fieldName: "cancelDisabled" },
      variant: "brand"
    }
  }
];

/** S-11-06 活性条件：PENDING／CONFIRMED のみ活性（RULE-05/07） */
function isCancellable(status) {
  return status === STATUS_PENDING || status === STATUS_CONFIRMED;
}

/** ポーリング終態（CD-08：SUCCEEDED／CONFLICT／FAILED） */
function isTerminalCommandStatus(status) {
  return (
    status === STATUS_SUCCEEDED ||
    status === STATUS_CONFLICT ||
    status === STATUS_FAILED
  );
}

/** AppointmentDate__c を YYYY-MM-DD 文字列化（Apex Date は ISO yyyy-MM-dd で返る） */
function formatDateLabel(value) {
  if (!value) {
    return "";
  }
  const s = String(value);
  return s.length >= 10 ? s.slice(0, 10) : s;
}

export default class BookingProjectionList extends LightningElement {
  bookings = [];
  columns = COLUMNS;
  message; // 表示中メッセージ（MSG-01〜06）
  messageType; // "error" | "info"（表示スタイル用）
  processingStatus; // S-11-07 処理状態（canonical 原样）
  commandId; // 受付番号（MSG-06／ポーリング定位）
  wiredResult; // refreshApex 用 wire 結果
  pollTimer; // setInterval ハンドル
  pollElapsedMs = 0;
  cancelPending = false; // クリック防護（double-submit 競合窓・guard 用・描画対象外）
  pollInFlight = false; // ポーリング防重複（in-flight ロック・guard 用・描画対象外）

  @wire(getProjections)
  wiredProjections(result) {
    this.wiredResult = result;
    const { data, error } = result;
    if (data) {
      this.bookings = data.map((booking) => this.normalizeBooking(booking));
      // 0 件は異常にしない（MSG-01 相当・DD-02 §3.3 処理概要 1）
      this.showMessage(data.length === 0 ? MSG_01 : undefined, "info");
    } else if (error) {
      // wire 通信エラー→MSG-02（S-11 表示条件）
      this.bookings = [];
      this.showMessage(MSG_02, "error");
    }
  }

  /** 表示行へ正規化（S-11-09/10 は内部保持・非表示・SyncStatus__c は表示しない） */
  normalizeBooking(booking) {
    const cancellable = isCancellable(booking.Status__c);
    return {
      Id: booking.Id,
      BookingExternalId__c: booking.BookingExternalId__c, // S-11-10 内部（定位キー）
      CurrentVersion__c: booking.CurrentVersion__c, // S-11-09 内部（expectedVersion）
      AppointmentNumber__c: booking.AppointmentNumber__c,
      dateLabel: formatDateLabel(booking.AppointmentDate__c),
      TimeSlot__c: booking.TimeSlot__c,
      ServiceName__c: booking.ServiceName__c,
      Status__c: booking.Status__c,
      cancelDisabled: !cancellable,
      cancelTitle: cancellable ? "キャンセル" : MSG_04 // MSG-04 は非活性理由の title
    };
  }

  showMessage(text, type) {
    this.message = text;
    this.messageType = text ? type : undefined;
  }

  get hasBookings() {
    return this.bookings.length > 0;
  }

  get isPolling() {
    return this.pollTimer !== undefined;
  }

  get messageClass() {
    return this.messageType === "info"
      ? "slds-text-color_success"
      : "slds-text-color_error";
  }

  disconnectedCallback() {
    this.stopPolling();
  }

  /** S-11-06 キャンセル押下（lightning-datatable の rowaction） */
  handleCancel(event) {
    const row = event.detail.row;
    if (!row || row.cancelDisabled || this.isPolling || this.cancelPending) {
      return;
    }
    // クリック防護：await 前に同期的にロック（double-submit 競合窓を封じる・P1-2）
    this.cancelPending = true;
    // 拍板 5：確認ダイアログ（設計値の確認文言）・no-alert は仕様要件のため許容
    // eslint-disable-next-line no-alert
    if (!window.confirm(CONFIRM_CANCEL_MESSAGE)) {
      this.cancelPending = false; // 確認キャンセル時はロック解除（再試行可能）
      return;
    }
    this.submitCancellation(row)
      .catch((error) => {
        // submitCancel 異常：Apex message 優先・無ければ MSG-03
        this.showMessage(this.extractErrorMessage(error) || MSG_03, "error");
      })
      .finally(() => {
        // 失敗・成功問わずロック解除（成功時は isPolling が引き続きガード）
        this.cancelPending = false;
      });
  }

  /** コマンド受理（拍板 3：MSG-06 表示→3 秒ポーリング開始） */
  async submitCancellation(row) {
    const response = await submitCancel({
      bookingExternalId: row.BookingExternalId__c,
      expectedVersion: row.CurrentVersion__c
    });
    this.commandId = response.commandId;
    this.processingStatus = response.status; // QUEUED（S-11-07 初期表示）
    this.showMessage(
      MSG_06.replace("{commandId}", response.commandId),
      "info"
    );
    this.startPolling();
  }

  /** S-11-07 ポーリング開始（非 cacheable pollCommandStatus・3 秒間隔・最長 60 秒） */
  startPolling() {
    this.stopPolling();
    this.pollElapsedMs = 0;
    // 拍板 3：3 秒間隔 setInterval は仕様要件のため no-async-operation を許容
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.pollTimer = setInterval(() => {
      this.pollOnce();
    }, POLL_INTERVAL_MS);
  }

  stopPolling() {
    if (this.pollTimer !== undefined) {
      clearInterval(this.pollTimer);
      this.pollTimer = undefined;
    }
  }

  /** 1 回のポーリング（manual=true は再読み込みボタンによる即時実行・経過秒を消費しない） */
  async pollOnce(manual = false) {
    // ポーリング防重複：in-flight 中は即リターン（manual・定期 tick とも同一制約・P1-2）。
    // スキップされた tick は 60 秒予算を消費しない（manual が経過秒を消費しないのと同義）
    if (this.pollInFlight) {
      return;
    }
    this.pollInFlight = true;
    try {
      if (!manual) {
        this.pollElapsedMs += POLL_INTERVAL_MS;
        if (this.pollElapsedMs >= POLL_MAX_MS) {
          // 最長 60 秒で自動停止→MSG-02 提示＋再読み込みボタンで再取得可能
          this.stopPolling();
          this.showMessage(MSG_02, "error");
          return; // 60 秒上限の早期 return も finally でロック解放（ロック意味論を迂回しない）
        }
      }
      const result = await pollCommandStatus({ commandId: this.commandId });
      this.processingStatus = result.status; // S-11-07 canonical 原样
      if (result.status === STATUS_SUCCEEDED) {
        // 終態：一覧を再取得（S-11-05 更新 CANCELLED）
        this.stopPolling();
        if (this.wiredResult) {
          await refreshApex(this.wiredResult);
        }
      } else if (isTerminalCommandStatus(result.status)) {
        // CONFLICT／FAILED → MSG-05
        this.stopPolling();
        this.showMessage(MSG_05.replace("{status}", result.status), "error");
      }
    } catch (error) {
      // poll 通信エラー→MSG-02
      this.stopPolling();
      this.showMessage(MSG_02, "error");
    } finally {
      this.pollInFlight = false; // ロック必ず解放
    }
  }

  /** S-11-08 再読み込み：一覧を refreshApex＋ポーリング中は即時 1 回ポーリング。
   * in-flight 中の即時ポーリングは静かに譲る（在飛中の poll か次の tick で収束する・P1-2） */
  async handleReload() {
    if (this.isPolling) {
      await this.pollOnce(true);
    }
    if (this.wiredResult) {
      await refreshApex(this.wiredResult);
    }
  }

  extractErrorMessage(error) {
    return error?.body?.message || error?.message;
  }
}
