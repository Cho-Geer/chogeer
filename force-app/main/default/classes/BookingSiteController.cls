/**
 * @description Site 用予約コントローラ（P0-3・F-23/F-24・TERM-25）
 * 設計出典：DD-02 §3.3（クラス・3 メソッド・SOQL・例外処理の凍結設計値）・BD-03 §7（F-24）・
 * §10.1 F-32 表 1/表 2（凍結 2026-09-01・Create 集合 6 項目厳守）・CD-07/CD-08（状態値封闭集）・
 * CF-05 未決 1（UUID v4・commandId は SF 側 Apex 生成・correlationId は Queueable へ渡すのみ）。
 *
 * 処理概要（DD-02 §3.3 処理概要 1〜3）：
 *   1) getProjections：外部ユーザーの AccountId（User から取得）で Booking__c を絞り込み
 *     （行級範囲は with sharing＋Sharing Set・NFR-06・MV-07・テスト context でも適用を org 実証）。
 *     取得 0 件は空一覧（MSG-01 相当・異常にしない）。
 *   2) submitCancel：投影定位（0 件＝越権/不存在・AuraHandledException・レコード残さず・MSG-03 相当）→
 *     CANCELLED/COMPLETED は事前抑制（RULE-07・MSG-04 相当・コマンド生成しない）→
 *     Booking_Command__c を insert（F-32 表 2 Create ○ 6 項目のみ・CorrelationId__c は insert しない）→
 *     同一トランザクションで Queueable をエンキュー → commandId／QUEUED を即時返却（NFR-03）。
 *   3) getCommandStatus：Booking_Command__c.Status__c を返す（with sharing＝自己生成のみ可視）。
 *
 * FLS：SOQL は WITH SECURITY_ENFORCED（getProjections・submitCancel・getCommandStatus）。
 * DML（insert）は Aura 実行（system context）のため CRUD/FLS 非強制（F-32 表 2 注記の
 * Queueable system context と同枠・BD-03 §10.1 表後注記）。
 *
 * プラットフォーム事実（CHK-02・org 00DIT000002Kg4l2AC で実証済み 2026-09-03）：
 * (a) Sharing Set は Apex テスト context の runAs Community ユーザーにも適用される
 *     （runAs 2 ユーザー 2 Account の行級断言で実証：自 Account 2 件のみ可視・他 Account 不可視）。
 *     本クラスは with sharing のため行級範囲は OWD Private＋Sharing Set に従う。
 * (b) Community ユーザーテスト recipe：Profile「Customer Community Plus User」＋Contact（AccountId）＋
 *     PS 割当て（Booking_Contract_SiteUser）を確認済み（実証）。※ Test.getStandardNetworkId() は
 *     本 org（API 67・2026-09-03 実測）の Apex エンジンに存在しないため recipe から除外（実装コードでは不使用）。
 * (c) UUID v4：Apex にネイティブ UUID は無い。Crypto.generateBlobKey()／Crypto.getRandom() は
 *     本 org の Apex エンジンに存在しない（2026-09-03 実測・apiVersion 60.0/67.0 とも compile 不可）。
 *     実在確認済みの Crypto.getRandomLong()（各 8 バイト）を 2 回呼んで 16 バイト乱数を生成し、
 *     RFC 4122 v4 形式（version=4・variant=10）へ変換（CF-05 未決 1・小文字・ハイフン付き 36 桁）。
 * (d) submitCancel は同一トランザクションで enqueueJob するため、テストは HttpCalloutMock 必須
 *     （stopTest で Queueable 実走時に実 callout 試行される・S-4 実測パターン踏襲）。
 */
global with sharing class BookingSiteController {
  // ========== 定数（CD-08/CD-07 封闭集・RULE-13・F-32 表 2 Create 集合） ==========

  private static final String COMMAND_TYPE_CANCEL = 'CANCEL_BOOKING'; // RULE-13 唯一のコマンド種別
  private static final String STATUS_QUEUED = 'QUEUED'; // CD-08 受付済（実行待ち）
  private static final String STATUS_CANCELLED = 'CANCELLED'; // CD-07 終状態
  private static final String STATUS_COMPLETED = 'COMPLETED'; // CD-07 終状態

  // メッセージ（MSG-03/04 相当・最終文面は P0-4 で確定・BD-03 §5 未決 3）
  private static final String MSG_NOT_FOUND_OR_NO_PERMISSION = '対象の予約が見つからないか、操作する権限がありません。';
  private static final String MSG_NOT_CANCELLABLE = 'この予約は取り消しできない状態です。';

  // ========== F-23 投影照会（DD-02 §3.3 メソッド 1・F-32 表 1 Read 集合 9 項目） ==========

  /**
   * @description 自 Account の予約投影一覧を返す（読取専用・cacheable）。
   * 外部ユーザーの AccountId は User から取得し、Booking__c を Account__c で絞り込む
   * （行級範囲は with sharing＋Sharing Set・NFR-06・MV-07）。AccountId が無い
   * （非 Community ユーザー）場合は 0 件＝空一覧（MSG-01 相当・異常にしない）。
   */
  @AuraEnabled(cacheable = true)
  public static List<Booking__c> getProjections() {
    Id accountId = queryAccountId();
    if (accountId == null) {
      return new List<Booking__c>();
    }
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
        SyncStatus__c
      FROM Booking__c
      WHERE Account__c = :accountId
      WITH SECURITY_ENFORCED
    ];
  }

  // ========== F-24 コマンド受付（DD-02 §3.3 メソッド 2・BD-03 §7） ==========

  /**
   * @description 取消コマンドを受付ける。投影定位（0 件＝越権/不存在で AuraHandledException・
   * レコード残さず）→ 事前抑制（CANCELLED/COMPLETED は RULE-07 で拒否）→
   * Booking_Command__c を insert（F-32 表 2 Create ○ 6 項目のみ・CorrelationId__c は insert しない）→
   * 同一トランザクションで BookingCommandQueueable をエンキューし、commandId／QUEUED を即時返す
   */
  @AuraEnabled
  public static CommandResponse submitCancel(String bookingExternalId, Integer expectedVersion) {
    // 入力境界（BD-03 §7.5 受付失敗・MSG-03 相当・コマンド生成しない）
    if (String.isBlank(bookingExternalId) || expectedVersion == null) {
      throw new AuraHandledException(MSG_NOT_FOUND_OR_NO_PERMISSION);
    }

    // 投影定位（with sharing 行級・越権/不存在は取得 0 件・F-32 表 1）
    List<Booking__c> targets = [
      SELECT Id, Status__c, CurrentVersion__c
      FROM Booking__c
      WHERE BookingExternalId__c = :bookingExternalId
      WITH SECURITY_ENFORCED
    ];
    if (targets.isEmpty()) {
      // 越権アクセス（他 Account の直指定等）＝行級範囲で取得不能（MV-07・MSG-03 相当・レコード残さず）
      throw new AuraHandledException(MSG_NOT_FOUND_OR_NO_PERMISSION);
    }

    // 事前抑制（RULE-07・BD-03 §7.5・MSG-04 相当・コマンド生成しない・最終判定は Booking 側 409）
    if (targets[0].Status__c == STATUS_CANCELLED || targets[0].Status__c == STATUS_COMPLETED) {
      throw new AuraHandledException(MSG_NOT_CANCELLABLE);
    }

    // commandId／correlationId＝UUID v4（CF-05 未決 1・一意性のみ保証）。
    // correlationId は insert せず Queueable コンストラクタへ渡すのみ（F-32 表 2 Create 集合厳守）
    String commandId = generateUuidV4();
    String correlationId = generateUuidV4();

    // Booking_Command__c 生成（F-32 表 2 Create ○ 6 項目のみ）
    Booking_Command__c cmd = new Booking_Command__c(
      CommandId__c = commandId,
      BookingExternalId__c = bookingExternalId,
      CommandType__c = COMMAND_TYPE_CANCEL,
      ExpectedVersion__c = expectedVersion,
      RequestedBySalesforceUserId__c = UserInfo.getUserId(),
      Status__c = STATUS_QUEUED
    );
    insert cmd;

    // 同一トランザクションで Queueable エンキュー（BD-01 §2 注記・BD-03 §7.4・NFR-03 即時返却）
    System.enqueueJob(
      new BookingCommandQueueable(
        cmd.Id,
        commandId,
        bookingExternalId,
        expectedVersion,
        UserInfo.getUserId(),
        correlationId
      )
    );

    return new CommandResponse(commandId, STATUS_QUEUED);
  }

  // ========== F-24 状態ポーリング（DD-02 §3.3 メソッド 3・S-11-07） ==========

  /**
   * @description コマンド状態を返す（cacheable）。with sharing＝自己生成コマンドのみ可視
   * （OWD Private・F-32 表 2 注記）のため、不明・他ユーザー生成コマンドは 0 件→AuraHandledException
   */
  @AuraEnabled(cacheable = true)
  public static CommandStatus getCommandStatus(String commandId) {
    if (String.isBlank(commandId)) {
      throw new AuraHandledException(MSG_NOT_FOUND_OR_NO_PERMISSION);
    }
    List<Booking_Command__c> commands = [
      SELECT Id, Status__c
      FROM Booking_Command__c
      WHERE CommandId__c = :commandId
      WITH SECURITY_ENFORCED
    ];
    if (commands.isEmpty()) {
      throw new AuraHandledException(MSG_NOT_FOUND_OR_NO_PERMISSION);
    }
    return new CommandStatus(commands[0].Status__c);
  }

  // ========== 内部ヘルパー ==========

  /**
   * @description 実行ユーザーの AccountId を User から取得（DD-02 §3.3 処理概要 1・
   * 「外部ユーザーの AccountId（User から取得）」）。Community ユーザー以外は null
   */
  private static Id queryAccountId() {
    List<User> users = [
      SELECT Id, AccountId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0].AccountId;
  }

  /**
   * @description RFC 4122 v4 形式の UUID を生成（CF-05 未決 1・小文字・ハイフン付き 36 桁）。
   * Apex にネイティブ UUID は無いため、16 バイト乱数を Crypto.getRandomLong()（各 8 バイト・
   * org 00DIT000002Kg4l2AC で実在確認済み 2026-09-03）2 回から生成し 32 桁 hex へ変換して、
   * version（第 7 バイト上位ニブル＝4）と variant（第 9 バイト上位 2bit＝10）のビットを埋める。
   * 一意性のみ保証（順序性なし）
   */
  @TestVisible
  private static String generateUuidV4() {
    String hex = longToHex16(Crypto.getRandomLong()) + longToHex16(Crypto.getRandomLong());
    return hex.substring(0, 8)
      + '-' + hex.substring(8, 12)
      + '-' + '4' + hex.substring(13, 16)
      + '-' + '8' + hex.substring(17, 20)
      + '-' + hex.substring(20, 32);
  }

  /**
   * @description 64bit Long を 16 桁小文字 hex へ変換（Apex に Long.toHexString は無いため
   * ビット演算で手動変換・`&`／`>>>` は org 実測で利用可能）
   */
  private static String longToHex16(Long value) {
    String hexChars = '0123456789abcdef';
    String result = '';
    for (Integer i = 0; i < 16; i++) {
      Integer nibble = (Integer) (value & 15L);
      result = hexChars.substring(nibble, nibble + 1) + result;
      value = value >>> 4;
    }
    return result;
  }

  // ========== 内部モデル（LWC への返却値） ==========

  /**
   * @description submitCancel の即時応答（commandId／QUEUED・BD-03 §7.3 出力）
   */
  public class CommandResponse {
    @AuraEnabled
    public String commandId;

    @AuraEnabled
    public String status;

    public CommandResponse(String commandId, String status) {
      this.commandId = commandId;
      this.status = status;
    }
  }

  /**
   * @description getCommandStatus の応答（Status__c・S-11-07 ポーリング表示）
   */
  public class CommandStatus {
    @AuraEnabled
    public String status;

    public CommandStatus(String status) {
      this.status = status;
    }
  }
}
