/**
 * @description 予約キャンセルコマンドのバックグラウンド実行 Queueable（P0-3・F-25/F-26・TERM-22）
 * 設計出典：DD-02 §3.2（コンストラクタ 6 引数・処理チェーン・応答区分・監査フィールド）・
 * IF-02 §4（6 項目ペイロード・応答区分・envelope）・CD-08（コマンド状態 5 値封闭集）・
 * CD-12（ResultCode 7 値封闭集）・BD-03 §8（F-25）・§9（F-26）・CF-05（correlationId 再利用）。
 *
 * 処理チェーン（DD-02 §3.2 凍結値・ただし実行順はプラットフォーム制約に合わせて調整）：
 *   1) コマンド取得（SOQL）
 *   2) Named Credential（Booking_Integration_API・静的 Bearer Token をカスタムヘッダー経由で
 *      プラットフォームが注入）へ POST /v1/integrations/salesforce/booking-commands・setTimeout(10000)
 *   3) 応答区分（RULE-09/14・C-5 具体値・IF-02 §4.8）：
 *      200 → SUCCEEDED＋HttpStatus/ResultVersion/ResultCode 記録＋F-26 バージョンゲート付き結果書き戻し
 *      409 → CONFLICT（終状態・リトライしない）＋応答 currentVersion/correlationId を可能な限り記録
 *      429/503/timeout/その他予期しない 500 系 → AttemptCount+1・NextAttemptAt 記録・
 *        上限 2 回（総 3 試行）未達なら即時 enqueue（連鎖）・到達で FAILED
 *      400/401/403/404 → 終状態不写（Status 不変）・HttpStatus/LastError/ResultCode 記録のみ（RULE-14 注記）
 *   4) 監査フィールド（REQ-031）：CorrelationId/AttemptCount/HttpStatus/NextAttemptAt/LastError/ResultCode/ResultVersion
 *
 * === 実行順に関するプラットフォーム制約（実証 2026-09-03） ===
 * 同一トランザクション内で DML 後に Http.send を呼ぶと System.CalloutException
 * 「You have uncommitted work pending. Please commit or rollback before calling out」になる。
 * そのため「attempt 開始時 RUNNING 更新 → callout」の設計順はそのまま実装できず、
 * callout を先に実行し、その後の DML で状態・監査フィールドを書く順序とした
 * （Queueable の execute は単一トランザクションのため RUNNING は callout 中に外部から観測不能であり、
 * 再試行待ち状態＝RUNNING として一時的障害の書込時に観測可能な形で維持する）。
 *
 * === プラットフォーム事実（CHK-02・org 00DIT000002Kg4l2AC で実証済み 2026-09-03） ===
 * (a) Queueable チェーン enqueue（execute 内の System.enqueueJob）はテスト context の
 *     Test.stopTest() 内で System.AsyncException（最大スタック深度）を投げる（実証）。
 *     → テストは「順次シミュレーション」（stopTest 後に手動 enqueue→再度 stopTest）で駆動し、
 *       クラス側は scheduleRetry の enqueue を防御的に try/catch する（本番では enqueue は許可され
 *       通常 throw しない。テスト context のみ throw するためのガード）。
 * (b) Queueable から HTTP callout を行うには implements Database.AllowsCallouts が必須
 *     （未実装時は System.CalloutException「Callout not allowed from this future method」・実証）。
 *
 * === C-2 修订（2026-09-03） ===
 * A3 认证从动态 HS256 JWT 改为静态 Bearer Token・EC 認証パラメータ guardSecret＋
 * カスタムヘッダー Authorization: Bearer {!$Credential.guardSecret} によりプラットフォームが注入
 * （NC は HTTP ヘッダーの数式を許可 ON・Generate Authorization Header は OFF のまま）。
 * Apex 不设置认证头・认证单测不可断言（注入在 mock 后）→
 * 実機验证归 B-2/B-4 実装后冒烟。安全降级（防重放/防篡改）经用户拍板接受・RULE-03 幂等与 TLS 兜底。
 *
 * === F-26 結果書き戻しの実装判断 ===
 * BookingProjectionRest.receiveProjection(ProjectionRequest) は global static であり、
 * S-3 クラスを改修せずに直接再利用できる（version ゲート RULE-01・eventId 冪等 RULE-04・
 * upsert・SyncStatus='SYNCED' 書込を内包）。→ 専用直書込経路を作らず投影入口を再利用する
 * （BD-07 §3 境界制約・F-26 §9.4「書き戻し経路は通常の投影入口を再利用」）。
 * 書き戻し eventId は commandId を使用（コマンドごとの冪等キー・CF-05 一意性のみ保証）。
 * 投影入口が 409 を返す場合（canonicalVersion <= CurrentVersion・RULE-01 等号含む）は
 * 「スキップ・エラー扱いしない」（F-26 §9.4「より高い場合のみ更新」・§9.5「拒否は上書きしない」）。
 * 投影入口が 400/500 を返す場合（書き戻し失敗）は §9.5 に従い Booking__c.LastError/SyncStatus に記録し、
 * コマンドは SUCCEEDED のまま（専用直書込はせず同期管理フィールドのみ）。
 *
 * CD-08/CD-12 は封闭集：本クラスが書込む値は必ず集内の値のみ（新造しない）。
 */
global class BookingCommandQueueable implements Queueable, Database.AllowsCallouts {
  // ========== 定数（C-5 具体値・IF-02 §4.2） ==========

  @TestVisible
  private static final Integer MAX_ATTEMPTS = 3; // 総 3 試行（初回＋リトライ 2 回・C-5 確定値）

  @TestVisible
  private static final String NAMED_CREDENTIAL = 'Booking_Integration_API'; // TERM-21 計画名

  @TestVisible
  private static final String RESOURCE_PATH = '/v1/integrations/salesforce/booking-commands'; // IF-02 §4.2

  @TestVisible
  private static final Integer TIMEOUT_MS = 10000; // ShowcaseContactSyncService.setTimeout(10000) 実測踏襲

  @TestVisible
  private static final String COMMAND_TYPE = 'CANCEL_BOOKING'; // RULE-13 唯一のコマンド種別

  // ========== 状態コード（CD-08・CD-12 封闭集の値のみ使用） ==========

  @TestVisible
  private static final String STATUS_RUNNING = 'RUNNING';
  @TestVisible
  private static final String STATUS_SUCCEEDED = 'SUCCEEDED';
  @TestVisible
  private static final String STATUS_CONFLICT = 'CONFLICT';
  @TestVisible
  private static final String STATUS_FAILED = 'FAILED';

  @TestVisible
  private static final String RESULT_SUCCESS = 'SUCCESS';
  @TestVisible
  private static final String RESULT_CONFLICT = 'CONFLICT';
  @TestVisible
  private static final String RESULT_VALIDATION_ERROR = 'VALIDATION_ERROR';
  @TestVisible
  private static final String RESULT_NOT_FOUND = 'NOT_FOUND';
  @TestVisible
  private static final String RESULT_AUTH_ERROR = 'AUTH_ERROR';
  @TestVisible
  private static final String RESULT_TRANSIENT_ERROR = 'TRANSIENT_ERROR';
  @TestVisible
  private static final String RESULT_SYSTEM_ERROR = 'SYSTEM_ERROR';

  // ========== 例外クラス（ShowcaseContactSyncService 実測パターン踏襲） ==========

  /**
   * @description 呼出失敗例外（一時的障害・タイムアウト等）
   */
  public class CalloutFailureException extends Exception {
  }

  // ========== インスタンス状態（コンストラクタ 6 引数・DD-02 §3.2 設計値） ==========

  private final Id commandRecordId;
  private final String commandId;
  private final String bookingExternalId;
  private final Integer expectedVersion;
  private final String requestedBySalesforceUserId;
  private final String correlationId;

  /**
   * @description コンストラクタ（DD-02 §3.2：Booking_Command__c.Id・commandId・bookingExternalId・
   * expectedVersion・requestedBySalesforceUserId・correlationId）。リトライ時も同一 commandId の
   * 新インスタンスを生成して連鎖する（RULE-10 原 commandId 維持）
   */
  public BookingCommandQueueable(
    Id commandRecordId,
    String commandId,
    String bookingExternalId,
    Integer expectedVersion,
    String requestedBySalesforceUserId,
    String correlationId
  ) {
    this.commandRecordId = commandRecordId;
    this.commandId = commandId;
    this.bookingExternalId = bookingExternalId;
    this.expectedVersion = expectedVersion;
    this.requestedBySalesforceUserId = requestedBySalesforceUserId;
    this.correlationId = correlationId;
  }

  // ========== Queueable 実行（DD-02 §3.2 処理チェーン） ==========

  /**
   * @description Queueable 実行。コマンド取得→RUNNING 開始→呼出→応答区分→監査フィールド更新。
   * 例外はクラス内で捕捉し上流へ伝播しない（DD-02 §3.2 例外処理）
   */
  global void execute(QueueableContext context) {
    Booking_Command__c cmd = queryCommand(commandRecordId);
    if (cmd == null) {
      // コマンドレコードが存在しない（削除済み等）場合は何もしない
      return;
    }

    // 2) 呼出（Named Credential・IF-02 §4.2・setTimeout(10000)）。
    //    プラットフォーム制約（DML 後の callout 不可）のため callout を先に実行し、
    //    状態・監査フィールドは呼出後の DML で書く
    HttpResponse response;
    try {
      response = sendCommand();
    } catch (Exception ex) {
      // タイムアウト・callout 例外 → 一時的障害（RULE-09・C-5：timeout は 503/429 と同列）
      handleTransient(cmd, null, ex.getMessage());
      return;
    }

    // 3) 応答区分（RULE-09/14・IF-02 §4.8）
    handleResponse(cmd, response);
  }

  // ========== 呼出（IF-02 §4.2・§4.1 6 項目ペイロード） ==========

  /**
   * @description Named Credential への POST 呼出。認証ヘッダーはカスタムヘッダー
   * （数式許可 ON）によりプラットフォームが注入（C-2 修订 2026-09-03・静的 Bearer Token）
   */
  private HttpResponse sendCommand() {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:' + NAMED_CREDENTIAL + RESOURCE_PATH);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setTimeout(TIMEOUT_MS);
    request.setBody(buildPayload());
    return new Http().send(request);
  }

  /**
   * @description IF-02 §4.1 の 6 項目ペイロード（commandType 固定・UUID 等はコンストラクタ引数）
   */
  private String buildPayload() {
    Map<String, Object> payload = new Map<String, Object>{
      'commandType' => COMMAND_TYPE,
      'commandId' => this.commandId,
      'bookingExternalId' => this.bookingExternalId,
      'expectedVersion' => this.expectedVersion,
      'requestedBySalesforceUserId' => this.requestedBySalesforceUserId,
      'correlationId' => this.correlationId
    };
    return JSON.serialize(payload);
  }

  // ========== 応答区分（RULE-09/14・C-5・IF-02 §4.8） ==========

  /**
   * @description 応答区分に応じた状態・監査フィールド更新
   */
  private void handleResponse(Booking_Command__c cmd, HttpResponse response) {
    Integer status = response.getStatusCode();
    CommandResponse parsed = parseResponse(response);

    if (status == 200) {
      // 取消成功：終状態 SUCCEEDED＋結果書き戻し（F-26・RULE-14 明示 200 のみ終状態書込可）
      cmd.Status__c = STATUS_SUCCEEDED;
      cmd.HttpStatus__c = 200;
      cmd.ResultVersion__c = parsed.canonicalVersion;
      cmd.ResultCode__c = String.isNotBlank(parsed.resultCode) ? parsed.resultCode : RESULT_SUCCESS;
      cmd.LastError__c = null;
      applyCorrelationId(cmd);
      update cmd;
      writeBackCancellation(cmd, parsed.canonicalVersion);
    } else if (status == 409) {
      // 業務競合：終状態 CONFLICT（リトライしない・RULE-02/09・MV-09）
      cmd.Status__c = STATUS_CONFLICT;
      cmd.HttpStatus__c = 409;
      cmd.ResultCode__c = RESULT_CONFLICT;
      cmd.LastError__c = buildLastError(409, parsed.errorMessage);
      if (parsed.currentVersion != null) {
        cmd.CurrentVersion__c = parsed.currentVersion; // 409 応答値（F-32 表 #13）
      }
      if (String.isNotBlank(parsed.correlationId)) {
        cmd.CorrelationId__c = parsed.correlationId; // 応答 correlationId を可能な限り記録
      } else {
        applyCorrelationId(cmd);
      }
      update cmd;
    } else if (isTransient(status)) {
      // 一時的障害（429/503/timeout/その他予期しない 500 系）：AttemptCount+1・上限内で連鎖リトライ
      handleTransient(cmd, status, parsed.errorMessage);
    } else {
      // 400/401/403/404（および定義外）：終状態不写（Status 不変・QUEUED のまま）・エラー記録のみ
      // （RULE-14 注記・MV-11）
      cmd.HttpStatus__c = status;
      cmd.ResultCode__c = mapNonTerminalResultCode(status);
      cmd.LastError__c = buildLastError(status, parsed.errorMessage);
      applyCorrelationId(cmd);
      update cmd;
    }
  }

  /**
   * @description 一時的障害処理：AttemptCount+1・NextAttemptAt（再 enqueue 予定時刻・監査用）・
   * LastError 記録・上限（総 3 試行）未達なら即時 enqueue（連鎖）・到達で FAILED（C-5・MV-10）
   */
  private void handleTransient(Booking_Command__c cmd, Integer status, String errorMessage) {
    Integer attempt = (cmd.AttemptCount__c == null ? 0 : Integer.valueOf(cmd.AttemptCount__c)) + 1;
    cmd.AttemptCount__c = attempt;
    cmd.NextAttemptAt__c = DateTime.now();
    cmd.HttpStatus__c = status;
    cmd.ResultCode__c = (status == 429 || status == 503 || status == null)
      ? RESULT_TRANSIENT_ERROR
      : RESULT_SYSTEM_ERROR;
    cmd.LastError__c = buildLastError(status, errorMessage);
    applyCorrelationId(cmd);

    if (attempt >= MAX_ATTEMPTS) {
      cmd.Status__c = STATUS_FAILED; // 上限到達で終状態 FAILED（RULE-10・REQ-028）
    } else {
      // 上限未達：再試行待ちの観測可能な状態として RUNNING（CD-08・プラットフォーム制約により
      // callout 後のこの時点で書く＝設計「attempt 開始時 RUNNING」の実質的代替）
      cmd.Status__c = STATUS_RUNNING;
    }
    update cmd;

    if (attempt < MAX_ATTEMPTS) {
      scheduleRetry(cmd);
    }
  }

  /**
   * @description CorrelationId__c が未設定の場合にコンストラクタ引数値を再利用（CF-05）
   */
  private void applyCorrelationId(Booking_Command__c cmd) {
    if (cmd.CorrelationId__c == null) {
      cmd.CorrelationId__c = correlationId;
    }
  }

  /**
   * @description 同一 commandId の新インスタンスを連鎖 enqueue（RULE-10・C-5 即時）。
   * テスト context では chained enqueue が AsyncException を投げる（実証 (a)）ため捕捉し、
   * テストは「順次シミュレーション」で次試行を手動駆動する。本番では Queueable からの
   * enqueue は許可されるため通常発生しない（捕捉はテスト context 専用ガード）
   */
  private void scheduleRetry(Booking_Command__c cmd) {
    try {
      System.enqueueJob(
        new BookingCommandQueueable(
          cmd.Id,
          this.commandId,
          this.bookingExternalId,
          this.expectedVersion,
          this.requestedBySalesforceUserId,
          this.correlationId
        )
      );
    } catch (Exception ex) {
      // テスト context の chained enqueue AsyncException を捕捉（実証 (a)）。
      // 本番で enqueue が失敗した場合もコマンドは RUNNING＋AttemptCount 記録済みのため手動確認対象となる
    }
  }

  /**
   * @description 一時的障害判定：429/503 および 500 系・その他定義外は一時的障害扱い
   * （C-5「500 等は一時的障害に準ずる・その他未知応答も同扱い」・IF-02 §4.3）
   */
  private static Boolean isTransient(Integer status) {
    return !(status == 200 || status == 409 || status == 400 || status == 401 || status == 403 || status == 404);
  }

  /**
   * @description 非終態の ResultCode マッピング（CD-12・400/401/403/404 は終状態不写）
   */
  private static String mapNonTerminalResultCode(Integer status) {
    if (status == 400) {
      return RESULT_VALIDATION_ERROR;
    }
    if (status == 404) {
      return RESULT_NOT_FOUND;
    }
    if (status == 401 || status == 403) {
      return RESULT_AUTH_ERROR;
    }
    return RESULT_SYSTEM_ERROR; // 定義外は SYSTEM_ERROR（CD-12 兜底）
  }

  // ========== 応答パース（IF-02 §4.3 envelope・api-contract の ApiResponseDto 形状） ==========

  /**
   * @description 応答ボディの envelope パース。data オブジェクトを優先し、なければトップレベルから
   * canonicalVersion/resultCode/currentVersion/correlationId/message を読む（寛容・未知キー無視）
   */
  private static CommandResponse parseResponse(HttpResponse response) {
    CommandResponse parsed = new CommandResponse();
    parsed.httpStatus = response.getStatusCode();
    String body = response.getBody();
    if (String.isBlank(body)) {
      return parsed;
    }
    try {
      Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
      Object dataObj = root.get('data');
      Map<String, Object> data = (dataObj instanceof Map<String, Object>) ? (Map<String, Object>) dataObj : null;
      Map<String, Object> primary = data != null ? data : root;
      parsed.canonicalVersion = readInteger(primary, 'canonicalVersion');
      parsed.resultCode = readString(primary, 'resultCode');
      parsed.currentVersion = readInteger(primary, 'currentVersion');
      parsed.correlationId = readString(primary, 'correlationId');
      parsed.errorMessage = readString(root, 'message');
      if (parsed.errorMessage == null) {
        parsed.errorMessage = readString(primary, 'message');
      }
    } catch (Exception ex) {
      parsed.errorMessage = '応答パース失敗: ' + ex.getMessage();
    }
    return parsed;
  }

  private static Integer readInteger(Map<String, Object> data, String key) {
    Object value = data.get(key);
    return value == null ? null : Integer.valueOf(String.valueOf(value));
  }

  private static String readString(Map<String, Object> data, String key) {
    Object value = data.get(key);
    return value == null ? null : String.valueOf(value);
  }

  /**
   * @description 応答モデル（IF-02 §4.3）
   */
  public class CommandResponse {
    public Integer httpStatus;
    public Integer canonicalVersion;
    public String resultCode;
    public Integer currentVersion;
    public String correlationId;
    public String errorMessage;
  }

  // ========== F-26 結果書き戻し（投影入口再利用・バージョンゲート付き） ==========

  /**
   * @description 成功後の結果書き戻し。Booking__c の CANCELLED 反映は通常の投影入口
   * BookingProjectionRest.receiveProjection を再利用し（S-3 無改修・BD-07 §3 境界制約）、
   * 専用直書込経路は作らない。incomingVersion（canonicalVersion）が CurrentVersion より高い場合のみ
   * 更新され、等号/旧版は投影入口の 409（RULE-01 等号含む）として「スキップ・エラー扱いしない」（F-26 §9.4/9.5）
   *
   * 書き戻し eventId＝commandId（コマンドごとの冪等キー・CF-05）。投影レコード未存在の場合は
   * 書き戻し対象が無いためスキップ（正本の投影は F-20 経由で既に存在する前提）。
   * P1-4 登録：書き戻し腿（S-3 再利用）は enqueue ユーザー身份で実行される（S-3 with sharing＋
   * WITH SECURITY_ENFORCED）。S-5 Site ユーザーが enqueue する将来経路では、システム context/
   * 権限継承の要否を S-5 設計で決定する（本クラスでは変更しない）
   */
  private void writeBackCancellation(Booking_Command__c cmd, Integer canonicalVersion) {
    if (canonicalVersion == null) {
      return; // 応答に canonicalVersion が無い場合は書き戻し不可（スキップ）
    }
    Booking__c existing = queryBookingForWriteback(this.bookingExternalId);
    if (existing == null) {
      return; // 投影未存在：スキップ（コマンドは SUCCEEDED のまま）
    }

    // 既存投影の表示項目を引き継ぎ CANCELLED 投影を投影入口へ送る（RULE-11 ホワイトリスト項目のみ）
    BookingProjectionRest.ProjectionRequest proj = new BookingProjectionRest.ProjectionRequest();
    proj.BookingExternalId = this.bookingExternalId;
    proj.AppointmentNumber = existing.AppointmentNumber__c;
    proj.AppointmentDate = existing.AppointmentDate__c != null ? String.valueOf(existing.AppointmentDate__c) : null;
    proj.TimeSlot = existing.TimeSlot__c;
    proj.ServiceName = existing.ServiceName__c;
    proj.Status = 'CANCELLED'; // canonical 値（BD-08 CD-03/CD-07 同一値）
    proj.version = canonicalVersion;
    proj.eventId = this.commandId; // 書き戻し eventId＝commandId
    proj.correlationId = this.correlationId;

    String envelopeJson = BookingProjectionRest.receiveProjection(proj);
    Integer writebackStatus = parseWritebackStatus(envelopeJson);

    if (writebackStatus == 200) {
      // 受理（canonicalVersion > CurrentVersion で更新完了）→ 追加処理なし
      return;
    }
    if (writebackStatus == 409) {
      // バージョンゲート拒否（等号/旧版）→ スキップ・エラー扱いしない（F-26 §9.4/9.5）
      return;
    }
    // 書き戻し失敗（400/500 等）→ §9.5：Booking__c の同期管理フィールドに記録（コマンドは SUCCEEDED のまま）。
    // P1-1：記録更新自体の失敗がコマンド終状態をロールバックさせないよう防御的に捕捉し、ログのみ残す
    try {
      Booking__c record = new Booking__c(Id = existing.Id);
      record.LastError__c = truncateForLastError('結果書き戻し失敗 (HTTP ' + writebackStatus + ')');
      record.SyncStatus__c = 'ERROR';
      update record;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'BookingCommandQueueable: 書き戻し失敗記録の更新に失敗（コマンドは SUCCEEDED のまま）: ' + ex.getMessage()
      );
    }
  }

  /**
   * @description 投影入口の envelope（success/statusCode/...）から statusCode を読む
   */
  private static Integer parseWritebackStatus(String envelopeJson) {
    if (String.isBlank(envelopeJson)) {
      return null;
    }
    try {
      Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(envelopeJson);
      Object statusCode = envelope.get('statusCode');
      return statusCode == null ? null : Integer.valueOf(String.valueOf(statusCode));
    } catch (Exception ex) {
      return null;
    }
  }

  /**
   * @description 書き戻し用の既存投影取得。表示項目（AppointmentNumber/Date/TimeSlot/ServiceName）を
   * 投影入口へ引き継ぐために参照する。Queueable は system context で状態・監査項目を更新する
   * 立場（F-32 表後注記）のため SECURITY_ENFORCED は付けない
   */
  private static Booking__c queryBookingForWriteback(String externalId) {
    List<Booking__c> records = [
      SELECT
        Id,
        BookingExternalId__c,
        AppointmentNumber__c,
        AppointmentDate__c,
        TimeSlot__c,
        ServiceName__c,
        CurrentVersion__c
      FROM Booking__c
      WHERE BookingExternalId__c = :externalId
      LIMIT 1
    ];
    return records.isEmpty() ? null : records[0];
  }

  // ========== コマンド取得・共通ヘルパー ==========

  /**
   * @description コマンドレコード取得（DD-02 §3.2 SOQL 要点）
   */
  private static Booking_Command__c queryCommand(Id id) {
    List<Booking_Command__c> records = [
      SELECT
        Id,
        CommandId__c,
        Status__c,
        AttemptCount__c,
        BookingExternalId__c,
        ExpectedVersion__c,
        RequestedBySalesforceUserId__c,
        CorrelationId__c
      FROM Booking_Command__c
      WHERE Id = :id
    ];
    return records.isEmpty() ? null : records[0];
  }

  /**
   * @description LastError 文言の組立（ステータス＋応答メッセージ）。P1-1：
   * 全 LastError__c 書込がこの中心関数を通る（255 桁制限へ截断）
   */
  private static String buildLastError(Integer status, String errorMessage) {
    String prefix = status == null ? 'Callout error' : ('HTTP ' + status);
    if (String.isNotBlank(errorMessage)) {
      return truncateForLastError(prefix + ': ' + errorMessage);
    }
    return prefix;
  }

  /**
   * @description LastError__c の 255 桁截断（P1-1 中心防护）。prefix（先頭）と末尾の
   * 重要情報を保持し中間を省略する（ヘッド 180 桁＋'...'＋テール 70 桁＝253 ≤ 255）
   */
  private static String truncateForLastError(String value) {
    if (value == null) {
      return null;
    }
    final Integer MAX_LENGTH = 255;
    if (value.length() <= MAX_LENGTH) {
      return value;
    }
    Integer headLength = 180;
    Integer tailLength = 70;
    return value.substring(0, headLength) + '...' + value.substring(value.length() - tailLength);
  }
}
