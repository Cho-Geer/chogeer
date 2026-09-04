/**
 * @description BookingSiteController 単体テスト（P0-3・unit-test-spec TC-12/13/15/16＋入力境界・
 * NFR-09 カバレッジ 75%）
 * 設計出典：unit-test-spec :68-69/71-72（TC-12/13/15/16）・DD-02 §3.3・BD-03 §7/§10.1 F-32 表 1/表 2・
 * CD-07/CD-08・CF-05 未決 1（UUID v4）・MV-07・RULE-07/13。
 *
 * テスト方式（PPT-01 †7：P0-3 実 callout なし）：
 * - (a) Sharing Set はテスト context の runAs Community ユーザーにも適用されることを org 実証済み
 *   （2026-09-03・runAs 2 ユーザー 2 Account の行級断言：自 Account 2 件のみ可視・他 Account 不可視）。
 *   → TC-12 は Sharing Set に基づく行級限定を直接断言する（fallback 設計は不要と確認）。
 * - (b) Community ユーザー recipe：Profile「Customer Community Plus User」＋Contact（AccountId）＋
 *   PS 割当て（Booking_Contract_SiteUser）。org 実証済み。※ Test.getStandardNetworkId() は
 *   本 org の Apex エンジンに存在しない（2026-09-03 実測・apiVersion 60.0/67.0 とも compile 不可）ため
 *   recipe から除外（Sharing Set 適用は本メソッド不要・プローブ実証済み）。
 * - (c) UUID v4 は BookingSiteController.generateUuidV4（@TestVisible）を形式・バージョンビットで断言
 *   （Crypto.generateBlobKey/getRandom は本 org に不在→getRandomLong×2 実装・形式断言で検証）。
 * - (d) TC-16 は submitCancel が同一トランザクションで enqueueJob するため HttpCalloutMock 必須
 *   （stopTest で Queueable 実走時に実 callout 試行される・S-4 実測パターン踏襲）。
 */
@isTest
private class BookingSiteControllerTest {
  // ========== fixture 定数（テストごとに一意な External ID） ==========

  private static final String EXTERNAL_A1 = 'S5-A1-' + String.valueOf(DateTime.now().getTime());
  private static final String EXTERNAL_A2 = 'S5-A2-' + String.valueOf(DateTime.now().getTime());
  private static final String EXTERNAL_B1 = 'S5-B1-' + String.valueOf(DateTime.now().getTime());

  private static Integer userSeq = 0;

  /**
   * @description テストコンテキスト（Account A/B/C・ユーザー A/B/C・投影 A 2 件/B 1 件）
   */
  private class Ctx {
    Account accA;
    Account accB;
    User userA;
    User userB;
    User userC;
  }

  /**
   * @description fixture 構築：Account A/B/C（C は投影なし）・投影（A に 2 件・B に 1 件 CANCELLED）・
   * Community ユーザー 3 名（recipe (b)・PS 割当て込み）
   */
  private static Ctx setup() {
    Ctx ctx = new Ctx();
    ctx.accA = new Account(Name = 'SiteTest-A');
    insert ctx.accA;
    ctx.accB = new Account(Name = 'SiteTest-B');
    insert ctx.accB;
    Account accC = new Account(Name = 'SiteTest-C');
    insert accC;

    // 投影（A に 2 件：PENDING/CONFIRMED・B に 1 件：CANCELLED・CD-07 値）
    insert new Booking__c(
      BookingExternalId__c = EXTERNAL_A1,
      AppointmentNumber__c = 'AP-S5-A1',
      AppointmentDate__c = Date.valueOf('2026-09-10'),
      TimeSlot__c = '10:00:00',
      ServiceName__c = 'テストサービスA',
      Status__c = 'PENDING',
      CurrentVersion__c = 1,
      Account__c = ctx.accA.Id,
      SyncStatus__c = 'SYNCED'
    );
    insert new Booking__c(
      BookingExternalId__c = EXTERNAL_A2,
      AppointmentNumber__c = 'AP-S5-A2',
      AppointmentDate__c = Date.valueOf('2026-09-11'),
      TimeSlot__c = '11:00:00',
      ServiceName__c = 'テストサービスA',
      Status__c = 'CONFIRMED',
      CurrentVersion__c = 2,
      Account__c = ctx.accA.Id,
      SyncStatus__c = 'SYNCED'
    );
    insert new Booking__c(
      BookingExternalId__c = EXTERNAL_B1,
      AppointmentNumber__c = 'AP-S5-B1',
      AppointmentDate__c = Date.valueOf('2026-09-12'),
      TimeSlot__c = '12:00:00',
      ServiceName__c = 'テストサービスB',
      Status__c = 'CANCELLED',
      CurrentVersion__c = 3,
      Account__c = ctx.accB.Id,
      SyncStatus__c = 'SYNCED'
    );

    ctx.userA = createCommunityUser(ctx.accA.Id, 'SiteUserA');
    ctx.userB = createCommunityUser(ctx.accB.Id, 'SiteUserB');
    ctx.userC = createCommunityUser(accC.Id, 'SiteUserC');
    return ctx;
  }

  /**
   * @description Community ユーザー作成（recipe (b)・org 実証済み）：Profile「Customer Community Plus User」＋
   * Contact（AccountId）＋PS「Booking_Contract_SiteUser」割当て。
   * ※ Test.getStandardNetworkId() は本 org の Apex エンジンに存在しない（2026-09-03 実測）ため使用しない
   */
  private static User createCommunityUser(Id accountId, String label) {
    Profile profile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1];
    Contact contact = new Contact(AccountId = accountId, LastName = label);
    insert contact;

    userSeq++;
    String suffix = String.valueOf(DateTime.now().getTime()) + '-' + userSeq;
    User u = new User(
      Alias = (label + suffix).left(8),
      Email = label.toLowerCase() + suffix + '@test.example.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = label,
      LastName = 'SiteTest',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'Asia/Tokyo',
      ProfileId = profile.Id,
      ContactId = contact.Id,
      UserName = label.toLowerCase() + suffix + '@test.example.com'
    );

    // 設定オブジェクト（User・PermissionSetAssignment）の DML は runAs 内で実施して
    // MIXED_DML_OPERATION を回避する（正規 recipe・Salesforce ドキュメント記載のパターン）
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;
      // PS 割当て（クラスアクセス・オブジェクト権限・FLS の実体・F-32 凍結値）
      PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Booking_Contract_SiteUser' LIMIT 1];
      insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }
    return u;
  }

  /**
   * @description 簡易 HttpCalloutMock（(d)）：200＋canonicalVersion=expectedVersion+1＋resultCode=SUCCESS
   */
  public class SuccessCalloutMock implements HttpCalloutMock {
    public Integer callCount = 0;
    public String endpoint;
    public Integer canonicalVersion = 2;

    public HttpResponse respond(HttpRequest req) {
      callCount++;
      endpoint = req.getEndpoint();
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(
        '{"code":"SUCCESS","message":"ok","data":{"canonicalVersion":' +
          canonicalVersion +
          ',"resultCode":"SUCCESS"}}'
      );
      return res;
    }
  }

  // ========== TC-12 越権（行級限定・MV-07・unit-test-spec :68） ==========

  /**
   * @description ユーザー A の getProjections は A の 2 件のみ（B の 1 件は出ない・Sharing Set 行級・
   * (a) org 実証）・B の bookingExternalId で submitCancel → 拒否（AuraHandledException）・コマンド 0 件
   */
  @isTest
  static void tc12RowLevelIsolationAndRejection() {
    Ctx ctx = setup();

    System.runAs(ctx.userA) {
      List<Booking__c> projections = BookingSiteController.getProjections();
      Assert.areEqual(2, projections.size(), 'A の投影は 2 件のはず');
      Set<String> externalIds = new Set<String>();
      for (Booking__c b : projections) {
        externalIds.add(b.BookingExternalId__c);
      }
      Assert.isTrue(externalIds.contains(EXTERNAL_A1), 'A-1 が見えるべき');
      Assert.isTrue(externalIds.contains(EXTERNAL_A2), 'A-2 が見えるべき');
      Assert.isFalse(externalIds.contains(EXTERNAL_B1), 'B-1 は見えてはならない（行級限定）');
    }

    // 他 Account（B）の bookingExternalId 直指定 → 越権・拒否・コマンド生成なし
    System.runAs(ctx.userA) {
      try {
        BookingSiteController.submitCancel(EXTERNAL_B1, 3);
        Assert.fail('期待: AuraHandledException（越権拒否）');
      } catch (AuraHandledException expected) {
        // 期待どおり
      }
    }
    Assert.areEqual(0, [SELECT COUNT() FROM Booking_Command__c], 'コマンドは生成されないはず');
  }

  // ========== TC-13 事前抑制（RULE-07・BD-03 §7.5・unit-test-spec :69） ==========

  /**
   * @description CANCELLED 投影（B-1・ユーザー B から可視）に submitCancel → 事前抑制
   * （AuraHandledException・MSG-04 相当）・Booking_Command__c は生成されない
   */
  @isTest
  static void tc13PreSuppressionCancelled() {
    Ctx ctx = setup();
    Integer countBefore = [SELECT COUNT() FROM Booking_Command__c];

    System.runAs(ctx.userB) {
      try {
        BookingSiteController.submitCancel(EXTERNAL_B1, 3);
        Assert.fail('期待: AuraHandledException（事前抑制）');
      } catch (AuraHandledException expected) {
        // 期待どおり
      }
    }
    Assert.areEqual(countBefore, [SELECT COUNT() FROM Booking_Command__c], 'コマンド件数は不変のはず');
  }

  // ========== TC-15 投影 0 件（MSG-01 相当・unit-test-spec :71） ==========

  /**
   * @description 自 Account に投影がないユーザー C → 空一覧・例外なし
   */
  @isTest
  static void tc15EmptyProjectionList() {
    Ctx ctx = setup();

    System.runAs(ctx.userC) {
      List<Booking__c> projections = BookingSiteController.getProjections();
      Assert.areEqual(0, projections.size(), '投影 0 件は空一覧・異常にしない');
    }
  }

  // ========== TC-16 正常（コマンド生成・状態遷移ポーリング・unit-test-spec :72） ==========

  /**
   * @description submitCancel 成功 → commandId/QUEUED 返却・Booking_Command__c 1 件生成
   * （F-32 表 2 Create ○ 6 項目の値検証・CorrelationId__c は null）→ stopTest で Queueable 実走
   * （mock 200・(d)）→ SUCCEEDED へ更新。getCommandStatus ポーリング（QUEUED→admin 更新 RUNNING→
   * SUCCEEDED）も検証
   */
  @isTest
  static void tc16SubmitCancelAndPolling() {
    Ctx ctx = setup();
    SuccessCalloutMock mock = new SuccessCalloutMock();
    mock.canonicalVersion = 2; // expectedVersion(1) + 1
    Test.setMock(HttpCalloutMock.class, mock);

    String commandId;
    Test.startTest();
    System.runAs(ctx.userA) {
      BookingSiteController.CommandResponse resp = BookingSiteController.submitCancel(EXTERNAL_A1, 1);
      commandId = resp.commandId;
      Assert.isNotNull(commandId, 'commandId が返るべき');
      Assert.areEqual('QUEUED', resp.status, '即時応答 status は QUEUED のはず');

      // UUID v4 形式（CF-05 未決 1・8-4-4-4-12・version=4・variant=10）
      Assert.isTrue(
        Pattern.matches(
          '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          commandId
        ),
        'UUID v4 形式違反: ' + commandId
      );

      // ポーリング（QUEUED 読める）
      Assert.areEqual('QUEUED', BookingSiteController.getCommandStatus(commandId).status);
    }

    // コマンド 1 件・Create 6 項目の値検証・CorrelationId__c は null（F-32 表 2 Create 集合厳守）
    List<Booking_Command__c> cmds = [
      SELECT
        CommandId__c,
        BookingExternalId__c,
        CommandType__c,
        ExpectedVersion__c,
        RequestedBySalesforceUserId__c,
        Status__c,
        CorrelationId__c
      FROM Booking_Command__c
    ];
    Assert.areEqual(1, cmds.size(), 'コマンドは 1 件のはず');
    Booking_Command__c cmd = cmds[0];
    Assert.areEqual(commandId, cmd.CommandId__c);
    Assert.areEqual(EXTERNAL_A1, cmd.BookingExternalId__c);
    Assert.areEqual('CANCEL_BOOKING', cmd.CommandType__c);
    Assert.areEqual(1, Integer.valueOf(cmd.ExpectedVersion__c));
    Assert.areEqual(ctx.userA.Id, Id.valueOf(cmd.RequestedBySalesforceUserId__c), '要求者はユーザー A のはず');
    Assert.areEqual('QUEUED', cmd.Status__c);
    Assert.isNull(cmd.CorrelationId__c, 'CorrelationId__c は insert しない（Create 集合外）');

    // admin が RUNNING に更新 → ユーザー A のポーリングで RUNNING が読める
    update new Booking_Command__c(Id = cmd.Id, Status__c = 'RUNNING');
    System.runAs(ctx.userA) {
      Assert.areEqual('RUNNING', BookingSiteController.getCommandStatus(commandId).status);
    }

    Test.stopTest(); // Queueable 実走（mock 200）→ Status 更新

    Assert.areEqual(1, mock.callCount, 'Queueable が callout 1 回のはず');
    Assert.isNotNull(mock.endpoint);
    Assert.isTrue(mock.endpoint.contains('callout:Booking_Integration_API'), 'Named Credential 経由のはず');

    // 診断情報（写回不成立時の原因特定用）
    Booking_Command__c cmdAfter = [
      SELECT Status__c, HttpStatus__c, ResultCode__c, ResultVersion__c, LastError__c
      FROM Booking_Command__c
      WHERE Id = :cmd.Id
    ];
    List<AsyncApexJob> jobs = [
      SELECT Id, Status, ExtendedStatus
      FROM AsyncApexJob
      WHERE ApexClassId IN (SELECT Id FROM ApexClass WHERE Name = 'BookingCommandQueueable')
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    String jobInfo = jobs.isEmpty()
      ? 'no-job'
      : (jobs[0].Status + '|' + jobs[0].ExtendedStatus);

    // 写回結果（F-26・S-3 queryForUpdate の SECURITY_ENFORCED 除去後の成立確認・P1-1 Option 1）。
    // fixture CurrentVersion=1 ＜ mock canonicalVersion=2 → incomingVersion > CurrentVersion で写回受理
    List<Booking__c> writebackBookings = [
      SELECT Id, Status__c, SyncStatus__c, CurrentVersion__c, LastError__c
      FROM Booking__c
      WHERE BookingExternalId__c = :EXTERNAL_A1
    ];
    String writebackInfo = writebackBookings.isEmpty()
      ? 'no-booking'
      : (
          writebackBookings[0].Status__c
          + '|' + writebackBookings[0].SyncStatus__c
          + '|' + writebackBookings[0].CurrentVersion__c
          + '|' + writebackBookings[0].LastError__c
        );
    Assert.areEqual(
      'SUCCEEDED',
      cmdAfter.Status__c,
      'コマンド状態: ' + cmdAfter.Status__c
        + ' Http=' + cmdAfter.HttpStatus__c
        + ' Result=' + cmdAfter.ResultCode__c
        + ' ResVer=' + cmdAfter.ResultVersion__c
        + ' LastError=' + cmdAfter.LastError__c
        + ' Job=' + jobInfo
    );
    Assert.areEqual(1, writebackBookings.size(), '写回対象の投影が存在するはず（写回状態: ' + writebackInfo + ' Job=' + jobInfo + '）');
    Assert.areEqual(
      'CANCELLED',
      writebackBookings[0].Status__c,
      '写回で Status__c=CANCELLED になるはず（写回状態: ' + writebackInfo + ' Job=' + jobInfo + '）'
    );
    Assert.areEqual(
      'SYNCED',
      writebackBookings[0].SyncStatus__c,
      '写回で SyncStatus__c=SYNCED のはず（写回状態: ' + writebackInfo + '）'
    );
    Assert.areEqual(
      mock.canonicalVersion,
      Integer.valueOf(writebackBookings[0].CurrentVersion__c),
      'CurrentVersion__c は mock canonicalVersion のはず（写回状態: ' + writebackInfo + '）'
    );

    // 最終状態ポーリング（SUCCEEDED 読める）
    System.runAs(ctx.userA) {
      Assert.areEqual('SUCCEEDED', BookingSiteController.getCommandStatus(commandId).status);
    }
  }

  // ========== 入力境界（blank externalId／null expectedVersion→拒否・0 件） ==========

  /**
   * @description 入力境界：bookingExternalId blank／null／expectedVersion null → 拒否
   * （AuraHandledException）・Booking_Command__c 0 件
   */
  @isTest
  static void inputBoundaryRejected() {
    Ctx ctx = setup();

    System.runAs(ctx.userA) {
      try {
        BookingSiteController.submitCancel('', 1);
        Assert.fail('期待: AuraHandledException（blank externalId）');
      } catch (AuraHandledException expected) {
        // 期待どおり
      }
      try {
        BookingSiteController.submitCancel(null, 1);
        Assert.fail('期待: AuraHandledException（null externalId）');
      } catch (AuraHandledException expected) {
        // 期待どおり
      }
      try {
        BookingSiteController.submitCancel(EXTERNAL_A1, null);
        Assert.fail('期待: AuraHandledException（null expectedVersion）');
      } catch (AuraHandledException expected) {
        // 期待どおり
      }
    }
    Assert.areEqual(0, [SELECT COUNT() FROM Booking_Command__c], '入力境界ではコマンド 0 件のはず');
  }

  // ========== getCommandStatus 異常（不明コマンド） ==========

  /**
   * @description 不明な commandId → AuraHandledException（自己生成のみ可視・DD-02 §3.3）
   */
  @isTest
  static void unknownCommandRejected() {
    Ctx ctx = setup();

    System.runAs(ctx.userA) {
      try {
        BookingSiteController.getCommandStatus('00000000-0000-4000-8000-000000000000');
        Assert.fail('期待: AuraHandledException（不明コマンド）');
      } catch (AuraHandledException expected) {
        // AuraHandledException.getMessage() は Apex では 'Script-thrown exception' を返すため、
        // 文言は @TestVisible 定数で検証する（P1-1・BD-05 §3.1 MSG-03 と逐字一致）
        Assert.areEqual(
          'この操作は許可されていません',
          BookingSiteController.MSG_NOT_FOUND_OR_NO_PERMISSION,
          'MSG_NOT_FOUND_OR_NO_PERMISSION は MSG-03 文言のはず'
        );
      }
    }
  }

  // ========== pollCommandStatus（P0-4・拍板 2b・非 cacheable ポーリング変体） ==========

  /**
   * @description pollCommandStatus 正常：submitCancel（QUEUED 生成・( d ) mock 必須）→
   * 同一ユーザーから pollCommandStatus で QUEUED が読める（getCommandStatus と同挙動・共有ヘルパー）
   */
  @isTest
  static void pollCommandStatusReturnsStatus() {
    Ctx ctx = setup();
    SuccessCalloutMock mock = new SuccessCalloutMock();
    mock.canonicalVersion = 2; // expectedVersion(1) + 1
    Test.setMock(HttpCalloutMock.class, mock);

    String commandId;
    Test.startTest();
    System.runAs(ctx.userA) {
      BookingSiteController.CommandResponse resp = BookingSiteController.submitCancel(EXTERNAL_A1, 1);
      commandId = resp.commandId;
      Assert.isNotNull(commandId, 'commandId が返るべき');
      Assert.areEqual(
        'QUEUED',
        BookingSiteController.pollCommandStatus(commandId).status,
        'pollCommandStatus は QUEUED を返すはず'
      );
    }
    Test.stopTest();
  }

  /**
   * @description pollCommandStatus 異常：不明な commandId → AuraHandledException
   * （getCommandStatus と同じ拒否挙動・共有ヘルパー経由）
   */
  @isTest
  static void pollCommandStatusUnknownRejected() {
    Ctx ctx = setup();

    System.runAs(ctx.userA) {
      try {
        BookingSiteController.pollCommandStatus('00000000-0000-4000-8000-000000000000');
        Assert.fail('期待: AuraHandledException（不明コマンド）');
      } catch (AuraHandledException expected) {
        // AuraHandledException.getMessage() は Apex では 'Script-thrown exception' を返すため、
        // 文言は @TestVisible 定数で検証する（P1-1・BD-05 §3.1 MSG-03 と逐字一致）
        Assert.areEqual(
          'この操作は許可されていません',
          BookingSiteController.MSG_NOT_FOUND_OR_NO_PERMISSION,
          'pollCommandStatus の拒否も MSG-03 文言のはず'
        );
      }
    }
  }

  // ========== UUID v4（CF-05 未決 1・形式・バージョンビット） ==========

  /**
   * @description generateUuidV4：8-4-4-4-12 形式・小文字・version=4・variant=10（複数回）
   */
  @isTest
  static void uuidV4FormatAndVersionBits() {
    for (Integer i = 0; i < 20; i++) {
      String uuid = BookingSiteController.generateUuidV4();
      Assert.areEqual(36, uuid.length(), 'UUID は 36 桁のはず');
      Assert.isTrue(
        Pattern.matches(
          '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          uuid
        ),
        'UUID v4 形式違反: ' + uuid
      );
    }
  }

  // ========== PS classAccesses 実証（F-32・クラスアクセス付与） ==========

  /**
   * @description PS「Booking_Contract_SiteUser」が BookingSiteController のクラスアクセスを
   * 持つことを SetupEntityAccess で実証し、runAs Site ユーザーでコントローラ呼び出しが通る
   * （クラスアクセス＋オブジェクト権限＋FLS の実体）
   */
  @isTest
  static void psClassAccessGranted() {
    Ctx ctx = setup();

    PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Booking_Contract_SiteUser' LIMIT 1];
    Id classId = [SELECT Id FROM ApexClass WHERE Name = 'BookingSiteController' LIMIT 1].Id;
    Integer accessCount = [
      SELECT COUNT()
      FROM SetupEntityAccess
      WHERE ParentId = :ps.Id AND SetupEntityId = :classId
    ];
    Assert.areEqual(1, accessCount, 'PS にクラスアクセスが付与されているはず');

    System.runAs(ctx.userA) {
      List<Booking__c> projections = BookingSiteController.getProjections();
      Assert.areEqual(2, projections.size(), 'Site ユーザーからコントローラ呼び出しが通るはず');
    }
  }
}
