@isTest
public class PlatformEventTest {
  @isTest
  static void test() {
    // テストデータの作成：キューが存在しない場合は作成
    List<Group> queues = [
      SELECT Id, Type, DeveloperName
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = 'News_Queue'
    ];

    Group newsQueue;
    if (queues.isEmpty()) {
      // テストキューの作成
      newsQueue = new Group(
        Name = 'News Queue',
        DeveloperName = 'News_Queue',
        Type = 'Queue'
      );
      insert newsQueue;

      // QueueSObjectの関連付け
      QueueSObject queueSObject = new QueueSObject(
        QueueId = newsQueue.Id,
        SObjectType = 'Case'
      );
      insert queueSObject;
    } else {
      newsQueue = queues[0];
    }

    // システム管理者権限を持つユーザーの取得（日本語プロファイル名）
    User adminUser = [
      SELECT Id
      FROM User
      WHERE Profile.Name = 'システム管理者' AND IsActive = TRUE
      LIMIT 1
    ];

    System.runAs(adminUser) {
      Cloud_News__e newsEvent = new Cloud_News__e(
        Location__c = 'Mountain City',
        Urgent__c = true,
        News_Content__c = 'Test message.'
      );

      Test.startTest();
      Database.SaveResult sr = EventBus.publish(newsEvent);

      // プラットフォームイベントの即時配信をシミュレート
      Test.getEventBus().deliver();

      Test.stopTest();

      system.assertEquals(
        true,
        sr.isSuccess(),
        'プラットフォームイベントの公開に失敗しました'
      );

      List<Case> cases = [SELECT Id, Subject, Priority, OwnerId FROM Case];
      System.debug('作成されたケース: ' + cases);
      System.assertEquals(1, cases.size(), 'ケースが1つ作成されるはずです');

      if (!cases.isEmpty()) {
        Case createdCase = cases[0];
        System.assertEquals(
          'News team dispatch to Mountain City',
          createdCase.Subject,
          'ケースの件名が正しくありません'
        );
        System.assertEquals(
          'High',
          createdCase.Priority,
          'ケースの優先度が正しくありません'
        );
        System.assertEquals(
          newsQueue.Id,
          createdCase.OwnerId,
          'ケースの所有者がキューに設定されていません'
        );
      }
    }
  }

  @isTest
  static void testFlowCreatesPlatformEvent() {
    // Ensure queue exists (same as above)
    List<Group> queues = [
      SELECT Id, Type, DeveloperName
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = 'News_Queue'
    ];
    Group newsQueue;
    if (queues.isEmpty()) {
      newsQueue = new Group(
        Name = 'News Queue',
        DeveloperName = 'News_Queue',
        Type = 'Queue'
      );
      insert newsQueue;
      QueueSObject queueSObject = new QueueSObject(
        QueueId = newsQueue.Id,
        SObjectType = 'Case'
      );
      insert queueSObject;
    } else {
      newsQueue = queues[0];
    }

    User adminUser = [
      SELECT Id
      FROM User
      WHERE Profile.Name = 'システム管理者' AND IsActive = TRUE
      LIMIT 1
    ];

    System.runAs(adminUser) {
      // Create Aobject__c record with Ac__c = 'create01' to trigger the flow
      Aobject__c aObj = new Aobject__c(Ac__c = 'create01');

      Test.startTest();
      insert aObj;
      // The flow should create a Cloud_News__e platform event.
      // Deliver platform events synchronously so trigger fires.
      Test.getEventBus().deliver();
      Test.stopTest();

      // Verify that a Case was created by the trigger (since platform event published)
      List<Case> cases = [
        SELECT Id, Subject, Priority, OwnerId, Description
        FROM Case
      ];
      System.assertEquals(1, cases.size(), 'ケースが1つ作成されるはずです');
      Case createdCase = cases[0];
      // Expect Subject: 'News team dispatch to 東京' (Location__c from flow)
      System.assertEquals(
        'News team dispatch to 東京',
        createdCase.Subject,
        'ケースの件名が正しくありません'
      );
      // Priority should be 'Medium' because Urgent__c is false
      System.assertEquals(
        'Medium',
        createdCase.Priority,
        'ケースの優先度が正しくありません'
      );
      // Owner should be newsQueue
      System.assertEquals(
        newsQueue.Id,
        createdCase.OwnerId,
        'ケースの所有者がキューに設定されていません'
      );
      // Description should contain News_Content__c 'Lake load is closed'
      System.assertEquals(
        'Lake load is closed',
        createdCase.Description,
        'ケースの説明が正しくありません'
      );
    }
  }
}
