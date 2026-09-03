/**
 * @description BookingCommandQueueable 単体テスト（P0-3・unit-test-spec TC-07〜11＋TC-14 関連・NFR-09 カバレッジ 75%）
 * 設計出典：unit-test-spec :63-70（TC-07〜11・TC-14）・DD-02 §3.2・IF-02 §4・CD-08/CD-12・MV-08/09/10/11。
 *
 * テスト方式（PPT-01 †7：P0-3 実 callout なし）：
 * - HttpCalloutMock のみ使用。認証ヘッダーはプラットフォーム注入（EC 認証パラメータ guardSecret＋
 *   カスタムヘッダー方式・C-2 修订 2026-09-03）のため mock では観測不可（ヘッダー未設定＝null であることのみ検証）。
 *   実機での注入確認は B-2/B-4 実装後の冒烟に帰属。
 * - enqueue 元は S-5 BookingSiteController 未実装のためテスト内 System.enqueueJob で代替
 *   （DD-02 §3.2 呼出元設計との整合・S-5 実装時に置換・handoff §四.7）。
 * - TC-09/10 の連鎖リトライは「1 回の stopTest 前に 3 試行分を enqueue → stopTest 内で逐次実行」で駆動する。
 *   実証 (a)：テスト context の chained enqueue（stopTest 同期実行中の execute 内 enqueueJob）は
 *   AsyncException を投げ、かつ Test.startTest/stopTest は 1 テストメソッドにつき 1 回のみ許可。
 *   そのため各試行を予め 3 つ enqueue し、stopTest で独立トランザクションの async として順次実行させる
 *   （各 job は自身のトランザクションのため、テスト側 fixture の未コミット DML が callout を妨げない）。
 *   クラス内 scheduleRetry の enqueue は stopTest 中に AsyncException になるが捕捉され無害（実証）。
 *   async 実行機構そのものは TC-07/08/11 も検証する。
 */
@isTest
private class BookingCommandQueueableTest {
  // ========== 共通ヘルパー ==========

  private static final String USER_ID = '005000000000001';

  /**
   * @description Booking_Command__c fixture（Status=QUEUED・AttemptCount=0）
   */
  private static Booking_Command__c insertCommand(String commandId, String externalId, Integer expectedVersion, String correlationId) {
    Booking_Command__c cmd = new Booking_Command__c(
      CommandId__c = commandId,
      BookingExternalId__c = externalId,
      CommandType__c = 'CANCEL_BOOKING',
      ExpectedVersion__c = expectedVersion,
      RequestedBySalesforceUserId__c = USER_ID,
      CorrelationId__c = correlationId,
      Status__c = 'QUEUED',
      AttemptCount__c = 0
    );
    insert cmd;
    return cmd;
  }

  /**
   * @description 既存 Booking__c fixture（TC-07 等・投影入口の検証を通る必須 8 項目を充足）
   */
  private static Booking__c insertExistingBooking(String externalId, Integer version, String lastEventId, String status) {
    Booking__c booking = new Booking__c(
      BookingExternalId__c = externalId,
      AppointmentNumber__c = 'AP-20260903-0001',
      AppointmentDate__c = Date.valueOf('2026-09-03'),
      TimeSlot__c = '10:00:00',
      ServiceName__c = 'テストサービス',
      Status__c = status,
      CurrentVersion__c = version,
      LastEventId__c = lastEventId,
      CorrelationId__c = 'corr-' + lastEventId,
      SyncStatus__c = 'SYNCED'
    );
    insert booking;
    return booking;
  }

  private static Booking_Command__c queryCommand(Id id) {
    List<Booking_Command__c> records = [
      SELECT
        Id,
        CommandId__c,
        Status__c,
        AttemptCount__c,
        NextAttemptAt__c,
        HttpStatus__c,
        ResultCode__c,
        ResultVersion__c,
        CurrentVersion__c,
        CorrelationId__c,
        LastError__c
      FROM Booking_Command__c
      WHERE Id = :id
    ];
    return records.isEmpty() ? null : records[0];
  }

  private static List<Booking__c> queryBookings(String externalId) {
    return [
      SELECT
        Id,
        BookingExternalId__c,
        Status__c,
        CurrentVersion__c,
        LastEventId__c,
        CorrelationId__c,
        SyncStatus__c,
        LastError__c
      FROM Booking__c
      WHERE BookingExternalId__c = :externalId
    ];
  }

  private static Integer intOf(Object value) {
    return value == null ? null : Integer.valueOf(String.valueOf(value));
  }

  /**
   * @description コマンド Queueable を生成（テスト内 enqueue の代替呼出元・S-5 実装時に置換）
   */
  private static BookingCommandQueueable buildQueueable(Id commandRecordId, String commandId, String externalId, Integer expectedVersion, String correlationId) {
    return new BookingCommandQueueable(commandRecordId, commandId, externalId, expectedVersion, USER_ID, correlationId);
  }

  // ========== HttpCalloutMock（リクエスト検証内蔵） ==========

  /**
   * @description コマンド呼出 Mock。statuses/bodies を順に返し（末尾で固定）、
   * 各リクエストの endpoint/method/body 6 項目を検証して validationErrors に記録する
   * （認証ヘッダーはプラットフォーム注入のため未設定＝null であることのみ検証）
   */
  public class CommandCalloutMock implements HttpCalloutMock {
    public List<Integer> statuses;
    public List<String> bodies;
    public Integer callCount = 0;
    public HttpRequest lastRequest;
    public List<String> validationErrors = new List<String>();

    public HttpResponse respond(HttpRequest req) {
      callCount++;
      lastRequest = req;
      validateRequest(req);
      Integer idx = Math.min(callCount - 1, statuses.size() - 1);
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statuses[idx]);
      if (bodies != null && bodies.size() > idx && bodies[idx] != null) {
        res.setBody(bodies[idx]);
      }
      return res;
    }

    private void validateRequest(HttpRequest req) {
      // endpoint は Named Credential 経由（callout:Booking_Integration_API を含む）
      if (req.getEndpoint() == null || !req.getEndpoint().contains('callout:Booking_Integration_API')) {
        validationErrors.add('endpoint: ' + req.getEndpoint());
      }
      if (!'POST'.equals(req.getMethod())) {
        validationErrors.add('method: ' + req.getMethod());
      }
      // 認証ヘッダーはプラットフォーム注入（mock では観測不可）・実機検証は B-2/B-4 後
      if (req.getHeader('Authorization') != null) {
        validationErrors.add('auth header must be null: ' + req.getHeader('Authorization'));
      }
      // body 6 項目（IF-02 §4.1）
      String body = req.getBody();
      if (String.isBlank(body)) {
        validationErrors.add('body blank');
        return;
      }
      try {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        if (parsed == null || parsed.size() != 6) {
          validationErrors.add('body size: ' + (parsed == null ? 'null' : String.valueOf(parsed.size())));
        }
        List<String> required = new List<String>{
          'commandType', 'commandId', 'bookingExternalId', 'expectedVersion',
          'requestedBySalesforceUserId', 'correlationId'
        };
        for (String key : required) {
          if (parsed == null || !parsed.containsKey(key)) {
            validationErrors.add('missing body key: ' + key);
          }
        }
      } catch (Exception ex) {
        validationErrors.add('body unparsable: ' + ex.getMessage());
      }
    }
  }

  /**
   * @description read timeout を模擬する Mock：respond が System.CalloutException を投げる
   *（Http.send から伝播し、execute の一時障害経路へ入る）
   */
  public class TimeoutCalloutMock implements HttpCalloutMock {
    public Integer callCount = 0;
    public HttpResponse respond(HttpRequest req) {
      callCount++;
      throw new CalloutException('read timed out');
    }
  }

  // ========== TC-07 正常（合法取消成功・結果書き戻し）（unit-test-spec :63・MV-08） ==========

  /**
   * @description Mock 200＋canonicalVersion=2＋resultCode → コマンド SUCCEEDED・HttpStatus=200・
   * ResultVersion 記録・Booking__c.Status__c=CANCELLED 書き戻し（バージョンゲート：1→2 受理）。
   * リクエスト検証（endpoint/POST/body 6 項目・認証ヘッダー未設定）も実施
   */
  @isTest
  static void tc07SuccessWritesBackCancellation() {
    String commandId = 'tc07-cmd-0001';
    String externalId = 'tc07-ext-0001';
    String correlationId = 'corr-tc07';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, correlationId);
    insertExistingBooking(externalId, 1, 'tc07-event-old', 'PENDING');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 200 };
    mock.bodies = new List<String>{ '{"code":"SUCCESS","message":"ok","data":{"canonicalVersion":2,"resultCode":"SUCCESS"}}' };
    Test.setMock(HttpCalloutMock.class, mock);

    // 呼出元（S-5）未実装につきテスト内 enqueue で代替
    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, correlationId));
    Test.stopTest();

    Assert.areEqual(0, mock.validationErrors.size(), String.join(mock.validationErrors, ';'));
    Assert.areEqual(1, mock.callCount);
    // リクエスト検証（Mock 内検証に加え最終リクエストの内容を明示確認）
    Assert.isTrue(mock.lastRequest.getEndpoint().contains('callout:Booking_Integration_API'));
    Assert.areEqual('POST', mock.lastRequest.getMethod());
    // 認証ヘッダーはプラットフォーム注入（mock では観測不可）・実機検証は B-2/B-4 後
    Assert.isNull(mock.lastRequest.getHeader('Authorization'));
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(mock.lastRequest.getBody());
    Assert.areEqual('CANCEL_BOOKING', (String) body.get('commandType'));
    Assert.areEqual(commandId, (String) body.get('commandId'));
    Assert.areEqual(externalId, (String) body.get('bookingExternalId'));
    Assert.areEqual(1, intOf(body.get('expectedVersion')));
    Assert.areEqual(USER_ID, (String) body.get('requestedBySalesforceUserId'));
    Assert.areEqual(correlationId, (String) body.get('correlationId'));

    // コマンド終状態（CD-08 SUCCEEDED・CD-12 SUCCESS）
    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('SUCCEEDED', updated.Status__c);
    Assert.areEqual(200, intOf(updated.HttpStatus__c));
    Assert.areEqual(2, intOf(updated.ResultVersion__c));
    Assert.areEqual('SUCCESS', updated.ResultCode__c);

    // F-26 結果書き戻し：Booking__c.Status__c=CANCELLED・CurrentVersion 2・SyncStatus=SYNCED
    List<Booking__c> bookings = queryBookings(externalId);
    Assert.areEqual(1, bookings.size());
    Assert.areEqual('CANCELLED', bookings[0].Status__c);
    Assert.areEqual(2, intOf(bookings[0].CurrentVersion__c));
    Assert.areEqual('SYNCED', bookings[0].SyncStatus__c);
    Assert.isNull(bookings[0].LastError__c);
    Assert.areEqual(commandId, bookings[0].LastEventId__c);
  }

  // ========== TC-08 異常（409 業務競合・リトライなし）（unit-test-spec :64・MV-09） ==========

  /**
   * @description Mock 409＋currentVersion=2＋correlationId → コマンド CONFLICT（終状態）・
   * リトライしない（AttemptCount 不変・呼出 1 回）・応答 currentVersion/correlationId 記録・
   * Booking__c 副作用なし
   */
  @isTest
  static void tc08ConflictNoRetry() {
    String commandId = 'tc08-cmd-0001';
    String externalId = 'tc08-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tc08');
    insertExistingBooking(externalId, 2, 'tc08-event-old', 'CONFIRMED');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 409 };
    mock.bodies = new List<String>{ '{"code":"CONFLICT","message":"version mismatch","data":{"currentVersion":3,"correlationId":"corr-booking-409"}}' };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc08'));
    Test.stopTest();

    Assert.areEqual(0, mock.validationErrors.size(), String.join(mock.validationErrors, ';'));
    Assert.areEqual(1, mock.callCount); // リトライしない

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('CONFLICT', updated.Status__c);
    Assert.areEqual(409, intOf(updated.HttpStatus__c));
    Assert.areEqual('CONFLICT', updated.ResultCode__c);
    Assert.areEqual(3, intOf(updated.CurrentVersion__c)); // 応答 currentVersion 記録
    Assert.areEqual('corr-booking-409', updated.CorrelationId__c); // 応答 correlationId 記録
    Assert.areEqual(0, intOf(updated.AttemptCount__c)); // リトライなし＝AttemptCount 不変
    Assert.isNotNull(updated.LastError__c);

    // Booking__c 副作用なし
    List<Booking__c> bookings = queryBookings(externalId);
    Assert.areEqual('CONFIRMED', bookings[0].Status__c);
    Assert.areEqual(2, intOf(bookings[0].CurrentVersion__c));
  }

  // ========== TC-09 異常（503 一時障害・成功回復・MV-10 上限ぎりぎり）（unit-test-spec :65） ==========

  /**
   * @description Mock 前 2 回 503・第 3 回 200 → AttemptCount が 2 回まで +1 され 3 回目成功で
   * SUCCEEDED（MV-10 上限ぎりぎり）。3 試行分を 1 回の stopTest 前に enqueue し、stopTest 内で
   * 逐次実行する（各 async job は独立トランザクションのため、テスト側 fixture の未コミット DML が
   * callout を妨げない・実証）。クラス内 scheduleRetry の enqueue は stopTest 中に AsyncException
   * になるが捕捉され無害（実証 (a)）。NextAttemptAt/LastError 記録は TC-09 の第 1・2 試行相当の
   * 途中状態として、最終状態（AttemptCount=2・SUCCEEDED）とあわせて検証する
   */
  @isTest
  static void tc09TransientTwiceThenSuccess() {
    String commandId = 'tc09-cmd-0001';
    String externalId = 'tc09-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tc09');
    insertExistingBooking(externalId, 1, 'tc09-event-old', 'PENDING');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 503, 503, 200 };
    mock.bodies = new List<String>{
      '{"code":"TRANSIENT_ERROR","message":"service unavailable","data":null}',
      '{"code":"TRANSIENT_ERROR","message":"service unavailable","data":null}',
      '{"code":"SUCCESS","message":"ok","data":{"canonicalVersion":2,"resultCode":"SUCCESS"}}'
    };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc09')); // 第 1 試行（503）
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc09')); // 第 2 試行（503）
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc09')); // 第 3 試行（200）
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('SUCCEEDED', updated.Status__c);
    Assert.areEqual(2, intOf(updated.AttemptCount__c)); // 2 回の失敗のみ +1・成功時は +1 されない
    Assert.areEqual(200, intOf(updated.HttpStatus__c));
    Assert.areEqual(2, intOf(updated.ResultVersion__c));
    Assert.areEqual('SUCCESS', updated.ResultCode__c);
    Assert.isNull(updated.LastError__c); // 最終成功で LastError クリア
    Assert.isNotNull(updated.NextAttemptAt__c); // P1-3：一時障害時の記録が残っている（成功でクリアされない）
    Assert.areEqual(3, mock.callCount);
    Assert.areEqual(0, mock.validationErrors.size(), String.join(mock.validationErrors, ';'));
  }

  // ========== TC-10 異常（継続失敗→FAILED）（unit-test-spec :66・MV-10・RULE-10） ==========

  /**
   * @description Mock 継続 503 → 上限（総 3 試行）到達で Status=FAILED・AttemptCount=3・
   * NextAttemptAt/LastError 記録（手動 Retry＝原 commandId 前提・RULE-10）。
   * 3 試行分を 1 回の stopTest 前に enqueue し、stopTest 内で逐次実行（各 async job は独立トランザクション）
   */
  @isTest
  static void tc10TransientExhaustedFailed() {
    String commandId = 'tc10-cmd-0001';
    String externalId = 'tc10-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tc10');
    insertExistingBooking(externalId, 1, 'tc10-event-old', 'PENDING');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 503, 503, 503 };
    mock.bodies = new List<String>{
      '{"code":"TRANSIENT_ERROR","message":"service unavailable","data":null}',
      '{"code":"TRANSIENT_ERROR","message":"service unavailable","data":null}',
      '{"code":"TRANSIENT_ERROR","message":"service unavailable","data":null}'
    };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc10'));
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc10'));
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc10'));
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('FAILED', updated.Status__c);
    Assert.areEqual(3, intOf(updated.AttemptCount__c));
    Assert.areEqual(503, intOf(updated.HttpStatus__c));
    Assert.areEqual('TRANSIENT_ERROR', updated.ResultCode__c);
    Assert.isNotNull(updated.NextAttemptAt__c);
    Assert.isNotNull(updated.LastError__c);
    Assert.areEqual(3, mock.callCount);
    Assert.areEqual(0, mock.validationErrors.size(), String.join(mock.validationErrors, ';'));

    // 書き戻しは成功時のみ（200 を受信していないため Booking__c 不変）
    List<Booking__c> bookings = queryBookings(externalId);
    Assert.areEqual('PENDING', bookings[0].Status__c);
    Assert.areEqual(1, intOf(bookings[0].CurrentVersion__c));
  }

  // ========== TC-11 異常（認証 NG 401・終状態不写）（unit-test-spec :67・MV-11） ==========

  /**
   * @description Mock 401 → コマンド終状態を書込まず（Status 不変＝QUEUED のまま・プラットフォーム制約で
   * callout 前に DML しないため attempt 開始 RUNNING は書かれない）・HttpStatus/LastError/ResultCode
   * （AUTH_ERROR）記録のみ・リトライなし・Booking__c 副作用なし
   */
  @isTest
  static void tc11AuthError401NoTerminalState() {
    String commandId = 'tc11-cmd-0001';
    String externalId = 'tc11-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tc11');
    insertExistingBooking(externalId, 1, 'tc11-event-old', 'PENDING');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 401 };
    mock.bodies = new List<String>{ '{"code":"AUTH_ERROR","message":"unauthorized","data":null}' };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc11'));
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('QUEUED', updated.Status__c); // 終状態不写（非終態保持・RULE-14 注記）
    Assert.areEqual(401, intOf(updated.HttpStatus__c));
    Assert.areEqual('AUTH_ERROR', updated.ResultCode__c);
    Assert.isNotNull(updated.LastError__c);
    Assert.areEqual(0, intOf(updated.AttemptCount__c)); // リトライしない
    Assert.areEqual(1, mock.callCount);

    List<Booking__c> bookings = queryBookings(externalId);
    Assert.areEqual('PENDING', bookings[0].Status__c);
  }

  /**
   * @description TC-11 の 403 分岐：Mock 403 → AUTH_ERROR・終状態不写（MV-11 分界）
   */
  @isTest
  static void tc11AuthError403NoTerminalState() {
    String commandId = 'tc11b-cmd-0001';
    String externalId = 'tc11b-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tc11b');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 403 };
    mock.bodies = new List<String>{ '{"code":"AUTH_ERROR","message":"forbidden","data":null}' };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc11b'));
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('QUEUED', updated.Status__c); // 終状態不写（非終態保持・MV-11 分界）
    Assert.areEqual(403, intOf(updated.HttpStatus__c));
    Assert.areEqual('AUTH_ERROR', updated.ResultCode__c);
    Assert.areEqual(0, intOf(updated.AttemptCount__c));
  }

  // ========== TC-14 関連：400 は終状態不写（unit-test-spec :70 注記） ==========

  /**
   * @description 受入端点の入力境界（P0 では Mock 応答の境界として検証）：Mock 400 →
   * Queueable 側は終状態不写（Status=RUNNING のまま）・ResultCode=VALIDATION_ERROR 記録のみ・
   * リトライなし（RULE-14 注記・CD-12）
   */
  @isTest
  static void tc14ValidationError400NoTerminalState() {
    String commandId = 'tc14-cmd-0001';
    String externalId = 'tc14-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tc14');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 400 };
    mock.bodies = new List<String>{ '{"code":"VALIDATION_ERROR","message":"bad request","data":null}' };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc14'));
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('QUEUED', updated.Status__c); // 終状態不写（非終態保持・400/404 は 200/409 のみ終状態の RULE-14 と整合）
    Assert.areEqual(400, intOf(updated.HttpStatus__c));
    Assert.areEqual('VALIDATION_ERROR', updated.ResultCode__c);
    Assert.isNotNull(updated.LastError__c);
    Assert.areEqual(0, intOf(updated.AttemptCount__c));
    Assert.areEqual(1, mock.callCount);
  }

  // ========== 追加カバレッジケース ==========

  /**
   * @description コマンドレコード不存在（削除済み等）→ execute は何もせず静かに戻る（DD-02 §3.2 例外処理）
   */
  @isTest
  static void commandNotFoundReturnsSilently() {
    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 200 };
    mock.bodies = new List<String>{ '{"code":"SUCCESS","message":"ok","data":{"canonicalVersion":1,"resultCode":"SUCCESS"}}' };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable('001000000000000000', 'tc-notfound-0001', 'tc-nf-ext-0001', 1, 'corr-nf'));
    Test.stopTest();

    Assert.areEqual(0, mock.callCount); // 呼出なし
  }

  /**
   * @description その他予期しない 500 系 → 一時的障害として SYSTEM_ERROR（CD-12・C-5）・
   * AttemptCount+1・上限内は RUNNING 維持
   */
  @isTest
  static void serverError500MappedSystemErrorAndTransient() {
    String commandId = 'tc500-cmd-0001';
    String externalId = 'tc500-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tc500');

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 500 };
    mock.bodies = new List<String>{ '{"code":"SYSTEM_ERROR","message":"internal","data":null}' };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tc500'));
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('RUNNING', updated.Status__c);
    Assert.areEqual(1, intOf(updated.AttemptCount__c));
    Assert.areEqual(500, intOf(updated.HttpStatus__c));
    Assert.areEqual('SYSTEM_ERROR', updated.ResultCode__c);
    Assert.isNotNull(updated.LastError__c);
  }

  /**
   * @description 書き戻し失敗（投影入口が 400 を返す＝既存投影の必須表示項目欠落）→
   * コマンドは SUCCEEDED のまま・Booking__c の LastError/SyncStatus に記録（F-26 §9.5）
   */
  @isTest
  static void writebackFailureRecordedOnBooking() {
    String commandId = 'tcwb-cmd-0001';
    String externalId = 'tcwb-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tcwb');
    // 表示項目を持たない既存投影（投影入口の必須検証が 400 になる）
    insert new Booking__c(
      BookingExternalId__c = externalId,
      Status__c = 'PENDING',
      CurrentVersion__c = 1,
      LastEventId__c = 'tcwb-event-old',
      SyncStatus__c = 'SYNCED'
    );

    CommandCalloutMock mock = new CommandCalloutMock();
    mock.statuses = new List<Integer>{ 200 };
    mock.bodies = new List<String>{ '{"code":"SUCCESS","message":"ok","data":{"canonicalVersion":2,"resultCode":"SUCCESS"}}' };
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tcwb'));
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('SUCCEEDED', updated.Status__c); // コマンドは SUCCEEDED のまま

    List<Booking__c> bookings = queryBookings(externalId);
    Assert.areEqual('ERROR', bookings[0].SyncStatus__c);
    Assert.isNotNull(bookings[0].LastError__c);
  }

  // ========== P1-3 追加：read timeout（CalloutException）→ 一時障害経路 ==========

  /**
   * @description Mock の respond が CalloutException（read timeout）を投げる → execute の一時障害
   * 経路（handleTransient）に入り、AttemptCount+1・TRANSIENT_ERROR・RUNNING（再試行待ち）・
   * NextAttemptAt/LastError 記録される（RULE-09・C-5：timeout は 503/429 と同列）
   */
  @isTest
  static void timeoutThrowsCalloutExceptionTransient() {
    String commandId = 'tcto-cmd-0001';
    String externalId = 'tcto-ext-0001';
    Booking_Command__c cmd = insertCommand(commandId, externalId, 1, 'corr-tcto');

    TimeoutCalloutMock mock = new TimeoutCalloutMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.enqueueJob(buildQueueable(cmd.Id, commandId, externalId, 1, 'corr-tcto'));
    Test.stopTest();

    Booking_Command__c updated = queryCommand(cmd.Id);
    Assert.areEqual('RUNNING', updated.Status__c); // 上限未達の再試行待ち
    Assert.areEqual(1, intOf(updated.AttemptCount__c));
    Assert.areEqual('TRANSIENT_ERROR', updated.ResultCode__c);
    Assert.isNull(updated.HttpStatus__c); // timeout は HTTP ステータス無し
    Assert.isNotNull(updated.NextAttemptAt__c);
    Assert.isNotNull(updated.LastError__c);
    Assert.areEqual(1, mock.callCount);
  }
}
