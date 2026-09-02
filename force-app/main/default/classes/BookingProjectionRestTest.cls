/**
 * @description BookingProjectionRest 単体テスト（P0-3・unit-test-spec TC-01〜06＋追加ケース）
 * 設計出典：unit-test-spec :57-62（TC-01〜06 期待結果）・NFR-09（カバレッジ 75% 以上）。
 * @isTest・seeAllData なし（org データ非参照）。
 */
@isTest
private class BookingProjectionRestTest {
  // ========== 共通ヘルパー ==========

  /**
   * @description ペイロード 9 項目の標準リクエスト組立（IF-01 §3.3）
   */
  private static BookingProjectionRest.ProjectionRequest buildRequest(
    String externalId,
    Integer version,
    String eventId
  ) {
    return buildRequest(externalId, version, eventId, 'PENDING');
  }

  private static BookingProjectionRest.ProjectionRequest buildRequest(
    String externalId,
    Integer version,
    String eventId,
    String status
  ) {
    BookingProjectionRest.ProjectionRequest request = new BookingProjectionRest.ProjectionRequest();
    request.BookingExternalId = externalId;
    request.AppointmentNumber = 'AP-20260902-0001';
    request.AppointmentDate = '2026-09-02';
    request.TimeSlot = '10:00:00';
    request.ServiceName = 'テストサービス';
    request.Status = status;
    request.version = version;
    request.eventId = eventId;
    request.correlationId = 'corr-' + eventId;
    return request;
  }

  /**
   * @description receiveProjection を直接呼出し（REST 転送なし・Test.invokeStaticResource 不要）、
   * envelope JSON を Map へ解析。Test.startTest/stopTest は各テストメソッド側で置く
   *（Apex は 1 テストメソッドにつき startTest 1 回のみのため・複数呼出は同一ペア内に包む）
   */
  private static Map<String, Object> call(BookingProjectionRest.ProjectionRequest request) {
    String body = BookingProjectionRest.receiveProjection(request);
    return (Map<String, Object>) JSON.deserializeUntyped(body);
  }

  private static Integer intOf(Object value) {
    return value == null ? null : Integer.valueOf(String.valueOf(value));
  }

  /**
   * @description TC-03/04 用の既存投影レコード作成（validation rule 合法値 version>=1 を使用）
   */
  private static void insertExistingBooking(String externalId, Integer version, String lastEventId) {
    insert new Booking__c(
      BookingExternalId__c = externalId,
      AppointmentNumber__c = 'AP-20260902-0002',
      AppointmentDate__c = Date.valueOf('2026-09-02'),
      TimeSlot__c = '11:00:00',
      ServiceName__c = '既存サービス',
      Status__c = 'PENDING',
      CurrentVersion__c = version,
      LastEventId__c = lastEventId,
      CorrelationId__c = 'corr-' + lastEventId,
      SyncStatus__c = 'SYNCED'
    );
  }

  private static List<Booking__c> queryBookings(String externalId) {
    return [
      SELECT
        Id,
        BookingExternalId__c,
        AppointmentNumber__c,
        AppointmentDate__c,
        TimeSlot__c,
        ServiceName__c,
        Status__c,
        CurrentVersion__c,
        LastEventId__c,
        CorrelationId__c,
        SyncStatus__c,
        LastError__c,
        Account__c,
        Admin_Note__c,
        LastModifiedDate
      FROM Booking__c
      WHERE BookingExternalId__c = :externalId
    ];
  }

  // ========== TC-01 初回投影成功（unit-test-spec :57） ==========

  /**
   * @description TC-01：新規予約の投影（version=1・新規 eventId・External ID 未存在）→
   * Booking__c 1 件 insert・Status__c/CurrentVersion__c がペイロード一致・
   * 応答 data に eventId＋受理後 currentVersion・SyncStatus__c='SYNCED'（F-20・MV-04）
   */
  @isTest
  static void tc01FirstProjectionSuccess() {
    Test.startTest();
    Map<String, Object> response = call(buildRequest('tc01-ext-0001', 1, 'tc01-event-0001'));
    Test.stopTest();

    Assert.areEqual(200, intOf(response.get('statusCode')));
    Assert.isTrue((Boolean) response.get('success'));
    Map<String, Object> data = (Map<String, Object>) response.get('data');
    Assert.areEqual('tc01-event-0001', (String) data.get('eventId'));
    Assert.areEqual(1, intOf(data.get('currentVersion')));

    List<Booking__c> records = queryBookings('tc01-ext-0001');
    Assert.areEqual(1, records.size());
    Assert.areEqual('PENDING', records[0].Status__c);
    Assert.areEqual(1, Integer.valueOf(records[0].CurrentVersion__c));
    Assert.areEqual('AP-20260902-0001', records[0].AppointmentNumber__c);
    Assert.areEqual('10:00:00', records[0].TimeSlot__c);
    Assert.areEqual('テストサービス', records[0].ServiceName__c);
    Assert.areEqual(Date.valueOf('2026-09-02'), records[0].AppointmentDate__c);
    Assert.areEqual('corr-tc01-event-0001', records[0].CorrelationId__c);
    Assert.areEqual('SYNCED', records[0].SyncStatus__c);
    Assert.areEqual('tc01-event-0001', records[0].LastEventId__c);
    Assert.isNull(records[0].LastError__c);
  }

  // ========== TC-02 冪等・同一 eventId 再送（unit-test-spec :58） ==========

  /**
   * @description TC-02：同一 eventId・同一 version 再送→200・レコード不増・不更新・
   * 初回受理結果をそのまま返す（RULE-04・LastEventId__c 判定・MV-05）。
   * LastModifiedDate 不変で「更新されていない」を厳密に検証
   */
  @isTest
  static void tc02SameEventIdResendIsIdempotent() {
    String externalId = 'tc02-ext-0001';
    String eventId = 'tc02-event-0001';
    Test.startTest();
    call(buildRequest(externalId, 1, eventId));
    Booking__c before = queryBookings(externalId)[0];

    Map<String, Object> response = call(buildRequest(externalId, 1, eventId));
    Test.stopTest();

    Assert.areEqual(200, intOf(response.get('statusCode')));
    Assert.isTrue((Boolean) response.get('success'));
    Map<String, Object> data = (Map<String, Object>) response.get('data');
    Assert.areEqual(eventId, (String) data.get('eventId'));
    Assert.areEqual(1, intOf(data.get('currentVersion')));

    List<Booking__c> records = queryBookings(externalId);
    Assert.areEqual(1, records.size());
    Assert.areEqual(before.CurrentVersion__c, records[0].CurrentVersion__c);
    Assert.areEqual(before.LastModifiedDate, records[0].LastModifiedDate);
    Assert.areEqual(eventId, records[0].LastEventId__c);
  }

  // ========== TC-03 旧 version 拒否（unit-test-spec :59） ==========

  /**
   * @description TC-03：CurrentVersion__c=5 の既存へ incomingVersion=4・新 eventId→
   * 409 競合応答・レコード不変（RULE-01・MV-05・REQ-024）。
   * details で現行 currentVersion が判別可能
   */
  @isTest
  static void tc03OldVersionRejected() {
    String externalId = 'tc03-ext-0001';
    insertExistingBooking(externalId, 5, 'tc03-event-old');

    Test.startTest();
    Map<String, Object> response = call(buildRequest(externalId, 4, 'tc03-event-new'));
    Test.stopTest();

    Assert.areEqual(409, intOf(response.get('statusCode')));
    Assert.isFalse((Boolean) response.get('success'));
    List<Object> errors = (List<Object>) response.get('errors');
    Map<String, Object> error = (Map<String, Object>) errors[0];
    Assert.areEqual('VERSION_CONFLICT', (String) error.get('code'));
    Map<String, Object> details = (Map<String, Object>) error.get('details');
    Assert.areEqual(5, intOf(details.get('currentVersion')));
    Assert.areEqual(4, intOf(details.get('incomingVersion')));
    Assert.areEqual('tc03-event-new', (String) details.get('eventId'));

    List<Booking__c> records = queryBookings(externalId);
    Assert.areEqual(1, records.size());
    Assert.areEqual(5, Integer.valueOf(records[0].CurrentVersion__c));
    Assert.areEqual('tc03-event-old', records[0].LastEventId__c);
  }

  // ========== TC-04 同 version・別 eventId は拒否（unit-test-spec :60） ==========

  /**
   * @description TC-04：CurrentVersion__c=5・LastEventId__c=旧 に対し incomingVersion=5・別 eventId→
   * 409（RULE-01 は等号を含む）・レコード不変
   */
  @isTest
  static void tc04SameVersionDifferentEventIdRejected() {
    String externalId = 'tc04-ext-0001';
    insertExistingBooking(externalId, 5, 'tc04-event-old');

    Test.startTest();
    Map<String, Object> response = call(buildRequest(externalId, 5, 'tc04-event-new'));
    Test.stopTest();

    Assert.areEqual(409, intOf(response.get('statusCode')));
    Assert.isFalse((Boolean) response.get('success'));
    List<Object> errors = (List<Object>) response.get('errors');
    Map<String, Object> details = (Map<String, Object>) ((Map<String, Object>) errors[0]).get('details');
    Assert.areEqual(5, intOf(details.get('currentVersion')));
    Assert.areEqual(5, intOf(details.get('incomingVersion')));

    List<Booking__c> records = queryBookings(externalId);
    Assert.areEqual(1, records.size());
    Assert.areEqual(5, Integer.valueOf(records[0].CurrentVersion__c));
    Assert.areEqual('tc04-event-old', records[0].LastEventId__c);
  }

  // ========== TC-05 並行初回投影（unit-test-spec :61） ==========

  /**
   * @description TC-05：並行初回投影の Apex 可測近似＝同一 External ID の順序二連発
   *（第一発 200 insert・第二発同 version 別 eventId→409・レコードは 1 件のみ）。
   *
   * 【誠実な限界宣言】Apex テストは真の並行を実行できない（単一スレッド・FOR UPDATE の
   * ロック保持期間中に別リクエストを投げる手段がない）。ここは順序シミュレーションであり、
   * 真並行（同時初回投影の競合）は MV-06 の設計（FOR UPDATE 行ロック＋upsert
   * DUPLICATE_EXTERNAL_ID 競合兜底リトライ）と org 実機冒烟（本タスク手順 4）で検証する。
   */
  @isTest
  static void tc05SequentialSimulatedConcurrentFirstProjection() {
    String externalId = 'tc05-ext-0001';

    Test.startTest();
    Map<String, Object> first = call(buildRequest(externalId, 1, 'tc05-event-a'));
    Map<String, Object> second = call(buildRequest(externalId, 1, 'tc05-event-b'));
    Test.stopTest();

    Assert.areEqual(200, intOf(first.get('statusCode')));
    Assert.areEqual(409, intOf(second.get('statusCode')));

    Assert.areEqual(1, [SELECT COUNT() FROM Booking__c WHERE BookingExternalId__c = :externalId]);
  }

  // ========== TC-06 PII 非含有（unit-test-spec :62） ==========

  /**
   * @description TC-06：投影後にレコードへ書込まれた全フィールドがホワイトリスト列のみであることを断言
   *（RULE-11 ホワイトリスト・REQ-019・NFR-08）。Booking__c オブジェクト自体に
   * 氏名/電話/メール/WeChat/備考の PII 5 項目フィールドは存在しないため、
   * 「構造的に PII を含み得ない」ことを書込済フィールド全数で検証する。
   * あわせて出典外の Account__c・Admin_Note__c が null 維持であることを検証
   */
  @isTest
  static void tc06NoPiiFieldsPopulated() {
    String externalId = 'tc06-ext-0001';
    Test.startTest();
    call(buildRequest(externalId, 1, 'tc06-event-0001'));
    Test.stopTest();

    Booking__c record = queryBookings(externalId)[0];

    // オブジェクト全 13 項目＋Id を照会済み（queryBookings）。書込済フィールドの全数検査
    Set<String> allowedFields = new Set<String>{
      'Id',
      'BookingExternalId__c',
      'AppointmentNumber__c',
      'AppointmentDate__c',
      'TimeSlot__c',
      'ServiceName__c',
      'Status__c',
      'CurrentVersion__c',
      'LastEventId__c',
      'CorrelationId__c',
      'SyncStatus__c',
      'LastError__c',
      'Account__c',
      'Admin_Note__c',
      'LastModifiedDate'
    };
    for (String fieldName : record.getPopulatedFieldsAsMap().keySet()) {
      Assert.isTrue(allowedFields.contains(fieldName), '範囲外フィールドへ書込あり（PII/出典外）: ' + fieldName);
    }

    // 出典外列は書かない（Account__c＝RULE-11 ホワイトリスト外・Admin_Note__c＝投影対象外）
    Assert.isNull(record.Account__c);
    Assert.isNull(record.Admin_Note__c);
  }

  // ========== 追加：入力検証 400 ==========

  /**
   * @description 追加ケース：必須検証 400（request null・BookingExternalId 欠落・version=0・version=-1・
   * version=null）。レコードは生成されない（IF-01 §3.3 必須・ADR-2b insert 境界）
   */
  @isTest
  static void inputValidationRejectsWith400() {
    Test.startTest();
    Map<String, Object> nullRequest = call(null);
    Map<String, Object> missingExternalId = call(buildRequest(null, 1, 'evt-1'));
    Map<String, Object> zeroVersion = call(buildRequest('tcv-ext-0001', 0, 'evt-2'));
    Map<String, Object> negativeVersion = call(buildRequest('tcv-ext-0001', -1, 'evt-3'));
    BookingProjectionRest.ProjectionRequest nullVersion = buildRequest('tcv-ext-0001', null, 'evt-4');
    Map<String, Object> response = call(nullVersion);
    Test.stopTest();

    Assert.areEqual(400, intOf(nullRequest.get('statusCode')));
    Assert.areEqual(400, intOf(missingExternalId.get('statusCode')));
    Assert.areEqual(400, intOf(zeroVersion.get('statusCode')));
    Assert.areEqual(400, intOf(negativeVersion.get('statusCode')));
    Assert.areEqual(400, intOf(response.get('statusCode')));

    Assert.areEqual(0, [SELECT COUNT() FROM Booking__c WHERE BookingExternalId__c = 'tcv-ext-0001']);
  }

  /**
   * @description 追加ケース：必須 8 項目の各欠落（ServiceName 以外の 6 項目を個別に）も 400 になること
   *（IF-01 §3.3 必須）。いずれもレコードを生成しない
   */
  @isTest
  static void missingEachRequiredFieldReturns400() {
    BookingProjectionRest.ProjectionRequest noNumber = buildRequest('tcm-ext-0001', 1, 'tcm-e1');
    noNumber.AppointmentNumber = null;
    BookingProjectionRest.ProjectionRequest noDate = buildRequest('tcm-ext-0001', 1, 'tcm-e2');
    noDate.AppointmentDate = null;
    BookingProjectionRest.ProjectionRequest noSlot = buildRequest('tcm-ext-0001', 1, 'tcm-e3');
    noSlot.TimeSlot = null;
    BookingProjectionRest.ProjectionRequest noStatus = buildRequest('tcm-ext-0001', 1, 'tcm-e4');
    noStatus.Status = null;
    BookingProjectionRest.ProjectionRequest noEvent = buildRequest('tcm-ext-0001', 1, null);
    BookingProjectionRest.ProjectionRequest noCorr = buildRequest('tcm-ext-0001', 1, 'tcm-e5');
    noCorr.correlationId = null;

    Test.startTest();
    Map<String, Object> r1 = call(noNumber);
    Map<String, Object> r2 = call(noDate);
    Map<String, Object> r3 = call(noSlot);
    Map<String, Object> r4 = call(noStatus);
    Map<String, Object> r5 = call(noEvent);
    Map<String, Object> r6 = call(noCorr);
    Test.stopTest();

    Assert.areEqual(400, intOf(r1.get('statusCode')));
    Assert.areEqual(400, intOf(r2.get('statusCode')));
    Assert.areEqual(400, intOf(r3.get('statusCode')));
    Assert.areEqual(400, intOf(r4.get('statusCode')));
    Assert.areEqual(400, intOf(r5.get('statusCode')));
    Assert.areEqual(400, intOf(r6.get('statusCode')));
    Assert.areEqual(0, [SELECT COUNT() FROM Booking__c WHERE BookingExternalId__c = 'tcm-ext-0001']);
  }

  /**
   * @description 追加ケース：契約形式逸脱（AppointmentDate が Date 変換不能）は入力検証を通過した後の
   * 未期例外として 500 envelope に変換されること（DD-02 §3.1 例外マッピング：未期→500）。
   * validateRequest は形式検証を行わない（契約外過剰検証の禁止・値域契約は送信側が担保）
   */
  @isTest
  static void unexpectedPayloadFormatReturns500Envelope() {
    BookingProjectionRest.ProjectionRequest request = buildRequest('tcu5-ext-0001', 1, 'tcu5-event-0001');
    request.AppointmentDate = 'not-a-date';

    Test.startTest();
    Map<String, Object> response = call(request);
    Test.stopTest();

    Assert.areEqual(500, intOf(response.get('statusCode')));
    Assert.isFalse((Boolean) response.get('success'));
    List<Object> errors = (List<Object>) response.get('errors');
    Assert.areEqual('INTERNAL_SERVER_ERROR', (String) ((Map<String, Object>) errors[0]).get('code'));
    Assert.areEqual(0, [SELECT COUNT() FROM Booking__c WHERE BookingExternalId__c = 'tcu5-ext-0001']);
  }

  /**
   * @description 追加ケース：DataAccessException（500 系・DD-02 §3.1 例外マッピング）が
   * operation/databaseErrors を保持する構造検証。DB 異常系（Security/Upsert 例外）はテスト
   * コンテキストから自然発生させられないため、例外クラス自体の契約を直接検証する
   */
  @isTest
  static void dataAccessExceptionCarriesOperationAndErrors() {
    BookingProjectionRest.DataAccessException ex = new BookingProjectionRest.DataAccessException(
      'テスト失敗',
      'UPSERT',
      new List<Database.Error>()
    );
    Assert.areEqual('テスト失敗', ex.getMessage());
    Assert.areEqual('UPSERT', ex.operation);
    Assert.isNotNull(ex.databaseErrors);
  }

  // ========== 追加：validation rule Version_Monotonic 直接 DML 検証 ==========

  /**
   * @description 追加ケース：直接 DML update による CurrentVersion__c 降級（5→4 相当の降級）は
   * validation rule Version_Monotonic で拒否される（ADR-2b・RULE-01 縦深防御）
   */
  @isTest
  static void validationRuleRejectsVersionDowngradeOnUpdate() {
    insertExistingBooking('tcvr-ext-0001', 3, 'tcvr-event-old');
    Booking__c record = queryBookings('tcvr-ext-0001')[0];
    record.CurrentVersion__c = 2;

    try {
      update record;
      Assert.fail('バージョン降級 update は validation rule で拒否されるべき（RULE-01）');
    } catch (DmlException ex) {
      Assert.isTrue(ex.getMessage().contains('版本单调性'), '期待エラー: 版本单调性違反, actual: ' + ex.getMessage());
    }
  }

  /**
   * @description 追加ケース：version=0 の直接 insert は validation rule Version_Monotonic で拒否される
   *（ADR-2b insert 境界）
   */
  @isTest
  static void validationRuleRejectsZeroVersionInsert() {
    Booking__c record = new Booking__c(
      BookingExternalId__c = 'tcvz-ext-0001',
      AppointmentNumber__c = 'AP-20260902-0003',
      AppointmentDate__c = Date.valueOf('2026-09-02'),
      TimeSlot__c = '12:00:00',
      Status__c = 'PENDING',
      CurrentVersion__c = 0
    );

    try {
      insert record;
      Assert.fail('version=0 の insert は validation rule で拒否されるべき（ADR-2b）');
    } catch (DmlException ex) {
      Assert.isTrue(ex.getMessage().contains('版本单调性'), '期待エラー: 版本单调性違反, actual: ' + ex.getMessage());
    }
  }

  // ========== 追加：REST 無引数アダプタ（@HttpPost 本体）のカバー（P1-1・复审修补） ==========

  /**
   * @description 追加ケース（P1-1）：@HttpPost 無引数アダプタの正常パス。RestContext.request に
   * 契約どおりの裸 9 項目 JSON（Map から生成・DTO 経由ではない＝属性名の干渉を避ける）を設定し、
   * アダプタ本体 receiveProjection() を直接呼出する。IF-01 §3.3 のワイヤ契約
   *（トップレベル裸オブジェクト・プラットフォームのパラメータ名包装を使わない）が
   * アダプタで受理されること・200 envelope・レコード insert を検証
   */
  @isTest
  static void adapterAcceptsValidRawPayload() {
    Map<String, Object> payload = new Map<String, Object>{
      'BookingExternalId' => 'tcad-ext-0001',
      'AppointmentNumber' => 'AP-20260902-0001',
      'AppointmentDate' => '2026-09-02',
      'TimeSlot' => '10:00:00',
      'ServiceName' => 'テストサービス',
      'Status' => 'PENDING',
      'version' => 1,
      'eventId' => 'tcad-event-0001',
      'correlationId' => 'corr-tcad-event-0001'
    };
    RestContext.request = new RestRequest();
    RestContext.request.requestBody = Blob.valueOf(JSON.serialize(payload));

    Test.startTest();
    String body = BookingProjectionRest.receiveProjection();
    Test.stopTest();

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(body);
    Assert.areEqual(200, intOf(response.get('statusCode')));
    Assert.isTrue((Boolean) response.get('success'));
    Map<String, Object> data = (Map<String, Object>) response.get('data');
    Assert.areEqual('tcad-event-0001', (String) data.get('eventId'));
    Assert.areEqual(1, intOf(data.get('currentVersion')));

    List<Booking__c> records = queryBookings('tcad-ext-0001');
    Assert.areEqual(1, records.size());
    Assert.areEqual(1, Integer.valueOf(records[0].CurrentVersion__c));
    Assert.areEqual('SYNCED', records[0].SyncStatus__c);
  }

  /**
   * @description 追加ケース（P1-1）：@HttpPost 無引数アダプタの壊 JSON パス。
   * JSON 解析失敗が 400 envelope・code=INVALID_JSON に変換されることを検証
   *（アダプタの INVALID_JSON 経路・エラー応答は 400）
   */
  @isTest
  static void adapterRejectsMalformedJson() {
    RestContext.request = new RestRequest();
    RestContext.request.requestBody = Blob.valueOf('{not-json');

    Test.startTest();
    String body = BookingProjectionRest.receiveProjection();
    Test.stopTest();

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(body);
    Assert.areEqual(400, intOf(response.get('statusCode')));
    Assert.isFalse((Boolean) response.get('success'));
    List<Object> errors = (List<Object>) response.get('errors');
    Assert.areEqual('INVALID_JSON', (String) ((Map<String, Object>) errors[0]).get('code'));
  }

  // ========== 追加：Upsert update パス（より高い version の受理） ==========

  /**
   * @description 追加ケース：既存レコードへより高い version＋新 eventId を送信→200・
   * CurrentVersion__c が受理後の値へ増加・LastEventId__c/Status 等 canonical 列が更新される
   *（BD-03 §3.7 更新対象エンティティ表）
   */
  @isTest
  static void upsertUpdatePathAcceptsHigherVersion() {
    String externalId = 'tcup-ext-0001';
    insertExistingBooking(externalId, 1, 'tcup-event-old');

    Test.startTest();
    Map<String, Object> response = call(buildRequest(externalId, 2, 'tcup-event-new', 'CONFIRMED'));
    Test.stopTest();

    Assert.areEqual(200, intOf(response.get('statusCode')));
    Assert.isTrue((Boolean) response.get('success'));
    Map<String, Object> data = (Map<String, Object>) response.get('data');
    Assert.areEqual('tcup-event-new', (String) data.get('eventId'));
    Assert.areEqual(2, intOf(data.get('currentVersion')));

    List<Booking__c> records = queryBookings(externalId);
    Assert.areEqual(1, records.size());
    Assert.areEqual(2, Integer.valueOf(records[0].CurrentVersion__c));
    Assert.areEqual('tcup-event-new', records[0].LastEventId__c);
    Assert.areEqual('CONFIRMED', records[0].Status__c);
    Assert.areEqual('corr-tcup-event-new', records[0].CorrelationId__c);
    Assert.areEqual('SYNCED', records[0].SyncStatus__c);
    Assert.isNull(records[0].LastError__c);
  }
}
