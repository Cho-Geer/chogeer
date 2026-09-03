/**
 * @description Booking→Salesforce 予約投影 受入口 Apex REST（P0-3・F-20・TERM-24）
 * 設計出典：DD-02 §3.1（処理チェーン・SOQL・Upsert・例外マッピングの凍結設計値）・
 * IF-01 §3.3〜§3.8（ペイロード 9 項目・冪等・異常マトリクス）・BD-03 §3.6/§3.7（FOR UPDATE・更新対象エンティティ）・
 * unit-test-spec TC-01〜06・ADR-2b（version >= 1 insert 境界）。
 *
 * パターン流用判断（流用＝パターン踏襲・DD-02 §3.1 流用要求に基づく）：標準 envelope（ApiResponse/ApiError）・
 * ValidationException/DataAccessException・handleXxxException 変換パターンは ShowcaseIntegrationRest.cls の
 * 実測パターンを踏襲する。ただし跨クラス参照は行わず同形クラスを本クラス内に定義する
 * （演示クラスと統合クラスの結合を避けるため）。
 *
 * 処理チェーン（DD-02 §3.1 凍結値・順序厳守）：
 *   1) 入力検証（必須 8 項目＝ServiceName 以外・version は 1 以上の整数）
 *   2) External ID で Booking__c を FOR UPDATE 行ロック取得（MV-06・BD-03 §3.6）
 *   3a) eventId 冪等判定をバージョンゲートに先行（RULE-04・零 DML）
 *   3b) バージョンゲート：incomingVersion <= CurrentVersion は拒否（RULE-01・等号含む）
 *   4) Upsert（部分成功許容・DD-02 §3.1 原文）
 *   5) External ID 一意制約競合（並行初回投影）は FOR UPDATE 再取得→再判定（最大 1 回）
 *   6) 受理成功応答：eventId・受理後 CurrentVersion（IF-01 §3.3）
 */
@RestResource(urlMapping='/integrations/bookings/projection')
global with sharing class BookingProjectionRest {
  // ========== 標準 envelope（ShowcaseIntegrationRest.ApiResponse と同形・本クラス内定義） ==========

  /**
   * @description 標準 REST API 応答 envelope（success/statusCode/message/data/errors/requestId/timestamp）
   */
  global class ApiResponse {
    @AuraEnabled
    public Boolean success { get; private set; }
    @AuraEnabled
    public Integer statusCode { get; private set; }
    @AuraEnabled
    public String message { get; private set; }
    @AuraEnabled
    public Object data { get; private set; }
    @AuraEnabled
    public List<ApiError> errors { get; private set; }
    @AuraEnabled
    public String requestId { get; private set; }
    @AuraEnabled
    public DateTime timestamp { get; private set; }

    /**
     * @description 成功応答コンストラクタ
     */
    public ApiResponse(Boolean success, Integer statusCode, String message, Object data) {
      this.success = success;
      this.statusCode = statusCode;
      this.message = message;
      this.data = data;
      this.errors = new List<ApiError>();
      this.requestId = generateRequestId();
      this.timestamp = DateTime.now();
    }

    /**
     * @description エラー応答コンストラクタ
     */
    public ApiResponse(Boolean success, Integer statusCode, String message, List<ApiError> errors) {
      this.success = success;
      this.statusCode = statusCode;
      this.message = message;
      this.data = null;
      this.errors = errors != null ? errors : new List<ApiError>();
      this.requestId = generateRequestId();
      this.timestamp = DateTime.now();
    }

    private String generateRequestId() {
      return 'REQ-' + DateTime.now().getTime() + '-' + Crypto.getRandomInteger();
    }
  }

  /**
   * @description API エラー詳細（code/message/field/details）
   */
  global class ApiError {
    @AuraEnabled
    public String code { get; private set; }
    @AuraEnabled
    public String message { get; private set; }
    @AuraEnabled
    public String field { get; private set; }
    @AuraEnabled
    public Object details { get; private set; }

    public ApiError(String code, String message, String field, Object details) {
      this.code = code;
      this.message = message;
      this.field = field;
      this.details = details;
    }
  }

  // ========== リクエストモデル（IF-01 §3.3 ペイロード 9 項目・RULE-11 ホワイトリスト凍結値） ==========

  /**
   * @description 投影ペイロード 9 項目。項目名は DD-02 §3.1 原文の契約（JSON キー）に厳密一致：
   * 前 6 項目は PascalCase・後 3 項目は version/eventId/correlationId のキャメルケース。
   * PII 5 項目（氏名/電話/メール/WeChat/備考）は構造的に含まれない（RULE-11・REQ-019・NFR-08）。
   *
   * 実装形態メモ：Apex REST のプラットフォーム側 JSON 逆直列化は public メンバー変数のみを認識し、
   * @AuraEnabled 付きプロパティ（get/set）は認識しない（org 実機検証：全キーが
   * JSON_PARSER_ERROR「Unexpected parameter」）。Salesforce 公式 DTO 惯例どおり
   * public メンバー変数で宣言する
   */
  global class ProjectionRequest {
    public String BookingExternalId;
    public String AppointmentNumber;
    public String AppointmentDate;
    public String TimeSlot;
    public String ServiceName;
    public String Status;
    public Integer version;
    public String eventId;
    public String correlationId;
  }

  // ========== 業務例外クラス ==========

  /**
   * @description 入力検証例外（400）
   */
  public class ValidationException extends Exception {
    public String errorCode { get; set; }
    public String fieldName { get; set; }

    public ValidationException(String errorCode, String message, String fieldName) {
      this.setMessage(message);
      this.errorCode = errorCode;
      this.fieldName = fieldName;
    }
  }

  /**
   * @description バージョン競合例外（409・RULE-01 バージョンゲート拒否）。
   * currentVersion/incomingVersion/eventId を保持し、競合応答の details で
   * 現行 version が判別可能にする（IF-01 §3.3 応答・TC-03/04）
   */
  public class VersionConflictException extends Exception {
    public Integer currentVersion { get; set; }
    public Integer incomingVersion { get; set; }
    public String eventId { get; set; }

    public VersionConflictException(Integer currentVersion, Integer incomingVersion, String eventId) {
      this.setMessage('バージョン競合：incomingVersion(' + incomingVersion + ') <= CurrentVersion(' + currentVersion + ') のため受理を拒否（RULE-01 単調増加・等号含む）');
      this.currentVersion = currentVersion;
      this.incomingVersion = incomingVersion;
      this.eventId = eventId;
    }
  }

  /**
   * @description データアクセス例外（500）
   */
  public class DataAccessException extends Exception {
    public String operation { get; set; }
    public List<Database.Error> databaseErrors { get; set; }

    public DataAccessException(String message, String operation, List<Database.Error> databaseErrors) {
      this.setMessage(message);
      this.operation = operation;
      this.databaseErrors = databaseErrors;
    }
  }

  // ========== REST エンドポイント ==========

  /**
   * @description REST 入口アダプタ（IF-01・TERM-24）。
   * プラットフォーム仕様メモ：Apex REST はトップレベル JSON キーをメソッドパラメータ名へ
   * バインドする（単一 typed パラメータ request の値は {"request": {...}} 包装形式となる）。
   * IF-01 §3.3 の凍結ワイヤ契約（ペイロード 9 項目＝トップレベル裸オブジェクト）を正として、
   * @HttpPost は無引数で受けて requestBody を JSON.deserialize（寛容：大文字小文字非依存・
   * 未知キー無視＝契約外過剰検証なし）し、検証以降の処理チェーンへ渡す。
   * DD-02 §3.1 の処理チェーン・検証・envelope・例外マッピングは無変更
   */
  @HttpPost
  global static String receiveProjection() {
    RestRequest req = RestContext.request;
    String body = (req != null && req.requestBody != null) ? req.requestBody.toString() : null;
    ProjectionRequest request = null;
    try {
      if (!String.isBlank(body)) {
        request = (ProjectionRequest) JSON.deserialize(body, ProjectionRequest.class);
      }
    } catch (Exception ex) {
      return handleValidationException(
        new ValidationException('INVALID_JSON', '请求体不是合法 JSON: ' + ex.getMessage(), null)
      );
    }
    return receiveProjection(request);
  }

  /**
   * @description 投影本処理入口（単体テスト・REST アダプタ双方から呼ばれる）。
   * Booking__c の唯一の書込入口（BD-07 §3 境界制約）
   * @param request 投影ペイロード 9 項目
   * @return 標準 envelope（JSON 文字列）
   */
  global static String receiveProjection(ProjectionRequest request) {
    // レスポンスヘッダ設定（ShowcaseIntegrationRest 実測パターン流用）
    RestResponse res = RestContext.response;
    if (res != null) {
      res.addHeader('Content-Type', 'application/json;charset=UTF-8');
      res.addHeader('X-Request-Id', 'REQ-' + DateTime.now().getTime() + '-' + Crypto.getRandomInteger());
    }

    try {
      // 1) 入力検証：必須 8 項目（ServiceName 以外）＋version は 1 以上の整数
      //    （version 下限＝ADR-2b insert 境界・validation rule Version_Monotonic と整合）
      validateRequest(request);

      // 2)〜6) 本処理（FOR UPDATE→冪等→バージョンゲート→Upsert→競合兜底）
      return processProjection(request, 0);
    } catch (ValidationException ex) {
      return handleValidationException(ex);
    } catch (VersionConflictException ex) {
      return handleVersionConflictException(ex);
    } catch (DataAccessException ex) {
      return handleDataAccessException(ex);
    } catch (Exception ex) {
      return handleUnexpectedException(ex);
    }
  }

  // ========== 処理チェーン（DD-02 §3.1 凍結値） ==========

  /**
   * @description 手順 2〜6：FOR UPDATE 定位→冪等判定→バージョンゲート→Upsert→競合兜底再試行
   * @param attempt 競合兜底の実施回数（最大 1 回）
   */
  private static String processProjection(ProjectionRequest request, Integer attempt) {
    // 2) External ID 定位・FOR UPDATE 行ロック（MV-06・BD-03 §3.6・DD-02 §3.1 指定列）
    Booking__c existing = queryForUpdate(request.BookingExternalId);

    if (existing != null) {
      // 3a) eventId 冪等判定をバージョンゲートに先行（RULE-04・TC-02）。
      //     同一 eventId の再送（同 version・同一 eventId を含む）は初回受理結果をそのまま返し零 DML
      if (request.eventId == existing.LastEventId__c) {
        return buildSuccessEnvelope(
          '同一 eventId 再送：初回受理結果を返す（RULE-04 冪等・更新なし）',
          request.eventId,
          existing.CurrentVersion__c
        );
      }

      // 3b) バージョンゲート：incomingVersion <= CurrentVersion は拒否（RULE-01・等号含む・TC-03/04）。
      //     初回 insert は比較対象外（既存レコードなしのため）
      if (request.version <= existing.CurrentVersion__c) {
        throw new VersionConflictException(
          Integer.valueOf(existing.CurrentVersion__c),
          request.version,
          request.eventId
        );
      }
    }

    // 4) Upsert（insert または update・部分成功許容・DD-02 §3.1 原文）。
    //    system context 実行は BookingProjectionDmlHelper（without sharing）へ委譲
    //    （2026-09-03・S-4 登記②解消の DML 側完結・用户拍板 Option 1）：
    //    with sharing（user mode）下では Site ユーザー（Booking__c Read のみ）の upsert が
    //    レコードアクセス検証で必ず失敗するため（実測）、写回 DML のみ明示 system context で実行。
    //    REST 経路＝A2 統合ユーザーは全権限のため挙動不変（ヘルパー呼出元は本投影入口のみ・他用途禁止）
    Booking__c record = buildProjectionRecord(request);
    List<Database.UpsertResult> results;
    try {
      results = new List<Database.UpsertResult>{
        BookingProjectionDmlHelper.upsertProjection(record)
      };
    } catch (Exception ex) {
      throw new DataAccessException('投影 Upsert に失敗しました: ' + ex.getMessage(), 'UPSERT', new List<Database.Error>());
    }

    Database.UpsertResult result = results[0];
    if (result.isSuccess()) {
      // 6) 受理成功応答：eventId・受理後 CurrentVersion（IF-01 §3.3 応答）
      return buildSuccessEnvelope('予約投影を受理しました', request.eventId, request.version);
    }

    // 5) 競合兜底（MV-06）：並行初回投影で External ID 一意制約競合（DUPLICATE_EXTERNAL_ID 系）の
    //    場合、FOR UPDATE 再取得→冪等/バージョンゲート再判定へ（最大 1 回・それでも失敗は 500）
    if (attempt < 1 && isExternalIdRaceError(result.getErrors())) {
      return processProjection(request, attempt + 1);
    }

    throw new DataAccessException('投影 Upsert に失敗しました', 'UPSERT', result.getErrors());
  }

  /**
   * @description 手順 2：External ID で Booking__c を FOR UPDATE 取得（DD-02 §3.1 指定列＋
   * system context（2026-09-03・S-4 登記②解消：Site ユーザー enqueue 経路の F-26 写回を成立させるため
   * SECURITY_ENFORCED を除去・with sharing 行級は維持・用户拍板 Option 1））
   */
  private static Booking__c queryForUpdate(String externalId) {
    try {
      List<Booking__c> records = [
        SELECT
          Id,
          CurrentVersion__c,
          LastEventId__c,
          SyncStatus__c,
          CorrelationId__c,
          LastError__c
        FROM Booking__c
        WHERE BookingExternalId__c = :externalId
        FOR UPDATE
      ];
      return records.isEmpty() ? null : records[0];
    } catch (Exception ex) {
      throw new DataAccessException('Booking__c 定位照会に失敗しました: ' + ex.getMessage(), 'QUERY', new List<Database.Error>());
    }
  }

  /**
   * @description 手順 4：投影レコード組立。書込対象＝ペイロード 9 項目対応列＋SyncStatus__c='SYNCED'＋
   * LastError__c=null（BD-03 §3.7 更新対象エンティティ表）。Account__c は書かない
   * （ペイロードに当該項目なし＝RULE-11 ホワイトリスト外・null 維持）
   */
  private static Booking__c buildProjectionRecord(ProjectionRequest request) {
    Booking__c booking = new Booking__c();
    booking.BookingExternalId__c = request.BookingExternalId;
    booking.AppointmentNumber__c = request.AppointmentNumber;
    booking.AppointmentDate__c = Date.valueOf(request.AppointmentDate);
    booking.TimeSlot__c = request.TimeSlot;
    booking.ServiceName__c = request.ServiceName;
    booking.Status__c = request.Status;
    booking.CurrentVersion__c = request.version;
    booking.LastEventId__c = request.eventId;
    booking.CorrelationId__c = request.correlationId;
    booking.SyncStatus__c = 'SYNCED';
    booking.LastError__c = null;
    return booking;
  }

  /**
   * @description Upsert 失敗が External ID 一意制約競合（並行初回投影の DUPLICATE 系）か判定
   */
  private static Boolean isExternalIdRaceError(List<Database.Error> errors) {
    for (Database.Error err : errors) {
      String code = String.valueOf(err.getStatusCode());
      String msg = err.getMessage() != null ? err.getMessage().toLowerCase() : '';
      if (code.contains('DUPLICATE') || msg.contains('duplicate')) {
        return true;
      }
    }
    return false;
  }

  // ========== 検証（IF-01 §3.3・ADR-2b） ==========

  /**
   * @description 入力検証：request 非null・必須 8 項目（ServiceName 以外は非blank）・
   * version は 1 以上の整数（ADR-2b insert 境界）。契約外の過剰検証はしない
   * （Status 値域・UUID 形式等は IF-01 §3.3 の値域契約に送信側が従う）
   */
  private static void validateRequest(ProjectionRequest request) {
    if (request == null) {
      throw new ValidationException('REQUEST_REQUIRED', '请求数据不能为空', null);
    }
    if (String.isBlank(request.BookingExternalId)) {
      throw new ValidationException('BOOKING_EXTERNAL_ID_REQUIRED', 'BookingExternalId 为必填（Upsert 定位键）', 'BookingExternalId');
    }
    if (String.isBlank(request.AppointmentNumber)) {
      throw new ValidationException('APPOINTMENT_NUMBER_REQUIRED', 'AppointmentNumber 为必填', 'AppointmentNumber');
    }
    if (String.isBlank(request.AppointmentDate)) {
      throw new ValidationException('APPOINTMENT_DATE_REQUIRED', 'AppointmentDate 为必填', 'AppointmentDate');
    }
    if (String.isBlank(request.TimeSlot)) {
      throw new ValidationException('TIME_SLOT_REQUIRED', 'TimeSlot 为必填', 'TimeSlot');
    }
    if (String.isBlank(request.Status)) {
      throw new ValidationException('STATUS_REQUIRED', 'Status 为必填', 'Status');
    }
    if (String.isBlank(request.eventId)) {
      throw new ValidationException('EVENT_ID_REQUIRED', 'eventId 为必填（幂等键）', 'eventId');
    }
    if (String.isBlank(request.correlationId)) {
      throw new ValidationException('CORRELATION_ID_REQUIRED', 'correlationId 为必填', 'correlationId');
    }
    if (request.version == null || request.version < 1) {
      throw new ValidationException('VERSION_INVALID', 'version 必须为 1 以上的整数（RULE-01 单调性・ADR-2b insert 边界）', 'version');
    }
  }

  // ========== 応答組立 ==========

  /**
   * @description 受理成功応答（200）：data={eventId, currentVersion}
   */
  private static String buildSuccessEnvelope(String message, String eventId, Decimal currentVersion) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 200;
    }
    Map<String, Object> data = new Map<String, Object>{
      'eventId' => eventId,
      'currentVersion' => currentVersion
    };
    return JSON.serialize(new ApiResponse(true, 200, message, data));
  }

  // ========== 例外→標準 envelope 変換（ShowcaseIntegrationRest handleXxxException パターン流用） ==========

  /**
   * @description 入力検証例外（400 Bad Request）
   */
  private static String handleValidationException(ValidationException ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 400;
    }
    ApiError error = new ApiError(
      ex.errorCode != null ? ex.errorCode : 'VALIDATION_ERROR',
      ex.getMessage(),
      ex.fieldName,
      null
    );
    return JSON.serialize(new ApiResponse(false, 400, '请求数据验证失败', new List<ApiError>{ error }));
  }

  /**
   * @description バージョン競合（409 Conflict・RULE-01）。details で現行 version が判別可能
   * （IF-01 §3.3「拒否と現行 version が判別可能な競合応答」）
   */
  private static String handleVersionConflictException(VersionConflictException ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 409;
    }
    Map<String, Object> details = new Map<String, Object>{
      'currentVersion' => ex.currentVersion,
      'incomingVersion' => ex.incomingVersion,
      'eventId' => ex.eventId
    };
    ApiError error = new ApiError('VERSION_CONFLICT', ex.getMessage(), 'CurrentVersion__c', details);
    return JSON.serialize(new ApiResponse(false, 409, '版本竞争冲突・受理被拒', new List<ApiError>{ error }));
  }

  /**
   * @description データアクセス例外（500 Internal Server Error）
   */
  private static String handleDataAccessException(DataAccessException ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 500;
    }
    List<Database.Error> dbErrors = ex.databaseErrors != null ? ex.databaseErrors : new List<Database.Error>();
    List<String> errorMessages = new List<String>();
    for (Database.Error dbError : dbErrors) {
      errorMessages.add(dbError.getStatusCode() + ': ' + dbError.getMessage());
    }
    ApiError error = new ApiError('DATA_ACCESS_ERROR', ex.getMessage(), ex.operation, errorMessages);
    return JSON.serialize(new ApiResponse(false, 500, '数据访问错误', new List<ApiError>{ error }));
  }

  /**
   * @description 未期例外（500 Internal Server Error）
   */
  private static String handleUnexpectedException(Exception ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 500;
    }
    ApiError error = new ApiError('INTERNAL_SERVER_ERROR', '系统内部错误', null, null);
    return JSON.serialize(new ApiResponse(false, 500, '系统内部错误', new List<ApiError>{ error }));
  }
}
