/**
 * bookingProjectionList 単体テスト（P0-4・BD-05 S-11-01〜10・MSG-01〜06・拍板 2b/3/5）
 *
 * カバレッジ：
 * - 一覧レンダリング（S-11-01〜05・日付 YYYY-MM-DD・内部項目保持・SyncStatus 非表示）＋空→MSG-01
 * - キャンセルボタン活性条件（PENDING/CONFIRMED 活性・CANCELLED/COMPLETED 非活性＋MSG-04）
 * - 確認ダイアログ（拍板 5）→ submitCancel → MSG-06 → pollCommandStatus 3 秒ポーリング →
 *   終態 SUCCEEDED → refreshApex の一連（拍板 3・2b）
 * - CONFLICT/FAILED → MSG-05 分岐・60 秒上限（jest フェイクタイマー）
 * - wire/poll 通信エラー→MSG-02・submitCancel 異常→Apex message 優先／無ければ MSG-03
 * - 再読み込みボタン（S-11-08）：refreshApex＋ポーリング中は即時 1 回ポーリング
 */
import { createElement } from "lwc";
import { createApexTestWireAdapter } from "@salesforce/sfdx-lwc-jest";

const mockRefreshApex = jest.fn().mockResolvedValue();

jest.mock(
  "@salesforce/apex",
  () => ({
    refreshApex: mockRefreshApex
  }),
  { virtual: true }
);

const mockGetProjectionsAdapter = createApexTestWireAdapter(jest.fn());

jest.mock(
  "@salesforce/apex/BookingSiteController.getProjections",
  () => ({
    default: mockGetProjectionsAdapter
  }),
  { virtual: true }
);

const mockSubmitCancel = jest.fn();

jest.mock(
  "@salesforce/apex/BookingSiteController.submitCancel",
  () => ({
    default: mockSubmitCancel
  }),
  { virtual: true }
);

const mockPollCommandStatus = jest.fn();

jest.mock(
  "@salesforce/apex/BookingSiteController.pollCommandStatus",
  () => ({
    default: mockPollCommandStatus
  }),
  { virtual: true }
);

const BookingProjectionList = require("c/bookingProjectionList").default;

const MSG_01 = "表示できる予約データがありません";
const MSG_02 = "データの取得に失敗しました。再読み込みしてください";
const MSG_03 = "この操作は許可されていません";
const MSG_04 = "この予約はキャンセルできません";

const mockBookings = [
  {
    Id: "a00Book000000001AAA",
    BookingExternalId__c: "ext-1",
    AppointmentNumber__c: "AP-20260910-0001",
    AppointmentDate__c: "2026-09-10",
    TimeSlot__c: "10:00:00",
    ServiceName__c: "テストサービスA",
    Status__c: "PENDING",
    CurrentVersion__c: 1,
    SyncStatus__c: "SYNCED"
  },
  {
    Id: "a00Book000000002AAA",
    BookingExternalId__c: "ext-2",
    AppointmentNumber__c: "AP-20260911-0002",
    AppointmentDate__c: "2026-09-11",
    TimeSlot__c: "11:00:00",
    ServiceName__c: "テストサービスA",
    Status__c: "CONFIRMED",
    CurrentVersion__c: 2,
    SyncStatus__c: "SYNCED"
  },
  {
    Id: "a00Book000000003AAA",
    BookingExternalId__c: "ext-3",
    AppointmentNumber__c: "AP-20260912-0003",
    AppointmentDate__c: "2026-09-12",
    TimeSlot__c: "12:00:00",
    ServiceName__c: "テストサービスB",
    Status__c: "CANCELLED",
    CurrentVersion__c: 3,
    SyncStatus__c: "SYNCED"
  },
  {
    Id: "a00Book000000004AAA",
    BookingExternalId__c: "ext-4",
    AppointmentNumber__c: "AP-20260913-0004",
    AppointmentDate__c: "2026-09-13",
    TimeSlot__c: "13:00:00",
    ServiceName__c: "テストサービスB",
    Status__c: "COMPLETED",
    CurrentVersion__c: 4,
    SyncStatus__c: "SYNCED"
  }
];

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve()).then(() => Promise.resolve());
}

function createComponent() {
  const element = createElement("c-booking-projection-list", {
    is: BookingProjectionList
  });
  document.body.appendChild(element);
  return element;
}

function emitProjections(element, data) {
  mockGetProjectionsAdapter.emit(data);
  return flushPromises();
}

/** window.confirm を決定的にスタブし、その spy を返す（拍板 5 の確認ダイアログ検証用） */
function stubConfirm(value) {
  window.confirm = jest.fn(() => value);
  return window.confirm;
}

/** lightning-datatable の rowaction イベントでキャンセルボタン相当の操作を再現 */
function clickCancelRow(element, index) {
  const dt = element.shadowRoot.querySelector("lightning-datatable");
  dt.dispatchEvent(
    new CustomEvent("rowaction", {
      detail: { row: dt.data[index], action: { name: "cancel" } }
    })
  );
}

describe("c-booking-projection-list", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    window.confirm = undefined;
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("renders the projection list (S-11-01..05) with formatted date, internal fields and no SyncStatus", async () => {
    const element = createComponent();
    await emitProjections(element, mockBookings);

    const dt = element.shadowRoot.querySelector("lightning-datatable");
    expect(dt).not.toBeNull();
    expect(dt.data).toHaveLength(4);

    // S-11-01..05 表示項目
    expect(dt.data[0].AppointmentNumber__c).toBe("AP-20260910-0001");
    expect(dt.data[0].dateLabel).toBe("2026-09-10"); // S-11-02 YYYY-MM-DD
    expect(dt.data[0].TimeSlot__c).toBe("10:00:00");
    expect(dt.data[0].ServiceName__c).toBe("テストサービスA");
    expect(dt.data[0].Status__c).toBe("PENDING"); // S-11-05 canonical 原样

    // S-11-09/10 内部保持（非表示列・定位/expectedVersion 用）
    expect(dt.data[0].BookingExternalId__c).toBe("ext-1");
    expect(dt.data[0].CurrentVersion__c).toBe(1);

    // SyncStatus__c は表示しない（BD-05 に表示項目なし）
    const fieldNames = dt.columns.map((col) => col.fieldName);
    expect(fieldNames).not.toContain("SyncStatus__c");
    expect(dt.columns).toHaveLength(6);
    expect(dt.columns[0].label).toBe("予約番号");
    expect(dt.columns[4].label).toBe("状態");

    expect(element.shadowRoot.textContent).not.toContain(MSG_01);
  });

  it("shows MSG-01 when the projection list is empty", async () => {
    const element = createComponent();
    await emitProjections(element, []);

    expect(element.shadowRoot.querySelector("lightning-datatable")).toBeNull();
    expect(element.shadowRoot.textContent).toContain(MSG_01);
  });

  it("shows MSG-02 when the Apex wire fails", async () => {
    const element = createComponent();
    mockGetProjectionsAdapter.error({ message: "boom" });
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-datatable")).toBeNull();
    expect(element.shadowRoot.textContent).toContain(MSG_02);
  });

  it("enables cancel only for PENDING/CONFIRMED and disables for CANCELLED/COMPLETED (S-11-06)", async () => {
    const element = createComponent();
    await emitProjections(element, mockBookings);

    const dt = element.shadowRoot.querySelector("lightning-datatable");
    expect(dt.data[0].cancelDisabled).toBe(false); // PENDING
    expect(dt.data[1].cancelDisabled).toBe(false); // CONFIRMED
    expect(dt.data[2].cancelDisabled).toBe(true); // CANCELLED
    expect(dt.data[3].cancelDisabled).toBe(true); // COMPLETED
    expect(dt.data[2].cancelTitle).toBe(MSG_04); // 非活性理由の title 提示

    // 非活性行の rowaction は確認ダイアログを開かず送信もしない
    clickCancelRow(element, 2);
    await flushPromises();
    expect(mockSubmitCancel).not.toHaveBeenCalled();
  });

  it("does not submit when the confirm dialog is declined (拍板 5)", async () => {
    const confirmSpy = stubConfirm(false);
    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    expect(confirmSpy).toHaveBeenCalled();
    expect(mockSubmitCancel).not.toHaveBeenCalled();
  });

  it("confirm -> submitCancel(MSG-06) -> poll every 3s -> SUCCEEDED -> refreshApex", async () => {
    jest.useFakeTimers();
    const confirmSpy = stubConfirm(true);
    const commandId = "11111111-1111-4111-8111-111111111111";
    mockSubmitCancel.mockResolvedValue({ commandId, status: "QUEUED" });
    mockPollCommandStatus
      .mockResolvedValueOnce({ status: "RUNNING" })
      .mockResolvedValue({ status: "SUCCEEDED" });

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    // 確認ダイアログ → submitCancel（bookingExternalId・expectedVersion）
    expect(confirmSpy).toHaveBeenCalled();
    expect(mockSubmitCancel).toHaveBeenCalledWith({
      bookingExternalId: "ext-1",
      expectedVersion: 1
    });

    // MSG-06 受理表示＋S-11-07 初期 QUEUED
    expect(element.shadowRoot.textContent).toContain(
      `キャンセルを受け付けました（受付番号：${commandId}）。状態が更新され次第表示されます`
    );
    expect(
      element.shadowRoot.querySelector("[data-processing-status]").textContent
    ).toBe("QUEUED");

    // 3 秒後：1 回目のポーリング（RUNNING）
    await jest.advanceTimersByTimeAsync(3000);
    expect(mockPollCommandStatus).toHaveBeenCalledTimes(1);
    expect(mockPollCommandStatus).toHaveBeenCalledWith({ commandId });
    expect(
      element.shadowRoot.querySelector("[data-processing-status]").textContent
    ).toBe("RUNNING");

    // さらに 3 秒後：SUCCEEDED → ポーリング停止・一覧 refreshApex・処理状態は終態
    await jest.advanceTimersByTimeAsync(3000);
    expect(mockPollCommandStatus).toHaveBeenCalledTimes(2);
    expect(mockRefreshApex).toHaveBeenCalledTimes(1);
    expect(
      element.shadowRoot.querySelector("[data-processing-status]").textContent
    ).toBe("SUCCEEDED");
  });

  it("shows MSG-05 and stops polling when the command reaches CONFLICT", async () => {
    jest.useFakeTimers();
    stubConfirm(true);
    mockSubmitCancel.mockResolvedValue({ commandId: "uuid-1", status: "QUEUED" });
    mockPollCommandStatus.mockResolvedValue({ status: "CONFLICT" });

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    await jest.advanceTimersByTimeAsync(3000);
    expect(element.shadowRoot.textContent).toContain(
      "キャンセル処理が完了しませんでした（状態：CONFLICT）。詳細は管理者に確認してください"
    );

    // ポーリング停止（それ以上呼ばれない）
    const calls = mockPollCommandStatus.mock.calls.length;
    await jest.advanceTimersByTimeAsync(9000);
    expect(mockPollCommandStatus.mock.calls.length).toBe(calls);
    expect(mockRefreshApex).not.toHaveBeenCalled();
  });

  it("shows MSG-05 when the command reaches FAILED", async () => {
    jest.useFakeTimers();
    stubConfirm(true);
    mockSubmitCancel.mockResolvedValue({ commandId: "uuid-1", status: "QUEUED" });
    mockPollCommandStatus.mockResolvedValue({ status: "FAILED" });

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    await jest.advanceTimersByTimeAsync(3000);
    expect(element.shadowRoot.textContent).toContain(
      "キャンセル処理が完了しませんでした（状態：FAILED）。詳細は管理者に確認してください"
    );
  });

  it("auto-stops polling after 60 seconds and shows MSG-02", async () => {
    jest.useFakeTimers();
    stubConfirm(true);
    mockSubmitCancel.mockResolvedValue({ commandId: "uuid-1", status: "QUEUED" });
    mockPollCommandStatus.mockResolvedValue({ status: "RUNNING" });

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    // 60 秒経過：3 秒間隔 × 19 回サーバーポーリング＋20 回目の tick で上限到達・自動停止
    await jest.advanceTimersByTimeAsync(60000);
    expect(mockPollCommandStatus).toHaveBeenCalledTimes(19);
    expect(element.shadowRoot.textContent).toContain(MSG_02);

    // 停止後は追加ポーリングされない（再読み込みボタンで再取得可能）
    const calls = mockPollCommandStatus.mock.calls.length;
    await jest.advanceTimersByTimeAsync(10000);
    expect(mockPollCommandStatus.mock.calls.length).toBe(calls);
  });

  it("shows MSG-02 and stops polling when a poll call fails", async () => {
    jest.useFakeTimers();
    stubConfirm(true);
    mockSubmitCancel.mockResolvedValue({ commandId: "uuid-1", status: "QUEUED" });
    mockPollCommandStatus.mockRejectedValue({ message: "network down" });

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    await jest.advanceTimersByTimeAsync(3000);
    expect(element.shadowRoot.textContent).toContain(MSG_02);
    expect(mockRefreshApex).not.toHaveBeenCalled();

    const calls = mockPollCommandStatus.mock.calls.length;
    await jest.advanceTimersByTimeAsync(6000);
    expect(mockPollCommandStatus.mock.calls.length).toBe(calls);
  });

  it("prefers the Apex message over MSG-03 when submitCancel rejects", async () => {
    stubConfirm(true);
    mockSubmitCancel.mockRejectedValue({
      body: { message: "対象の予約が見つからないか、操作する権限がありません。" }
    });

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "対象の予約が見つからないか、操作する権限がありません。"
    );
  });

  it("shows MSG-03 when submitCancel rejects without an Apex message", async () => {
    stubConfirm(true);
    mockSubmitCancel.mockRejectedValue({});

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(MSG_03);
  });

  it("reload button refreshes the list and triggers one immediate poll while polling (S-11-08)", async () => {
    jest.useFakeTimers();
    stubConfirm(true);
    mockSubmitCancel.mockResolvedValue({ commandId: "uuid-1", status: "QUEUED" });
    mockPollCommandStatus.mockResolvedValue({ status: "RUNNING" });

    const element = createComponent();
    await emitProjections(element, mockBookings);

    clickCancelRow(element, 0);
    await flushPromises();
    expect(mockRefreshApex).not.toHaveBeenCalled();

    const reload = element.shadowRoot.querySelector("[data-reload-button]");
    expect(reload).not.toBeNull();
    reload.click();
    await flushPromises();

    // ポーリング中は即時 1 回ポーリング＋一覧 refreshApex
    expect(mockPollCommandStatus).toHaveBeenCalledTimes(1);
    expect(mockRefreshApex).toHaveBeenCalledTimes(1);
  });
});
