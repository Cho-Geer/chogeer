@IsTest
public with sharing class CloudNewsServiceTest {
  @IsTest
  static void testCreateCasesFromEvents() {
    // 创建测试平台事件
    List<Cloud_News__e> events = new List<Cloud_News__e>();
    events.add(
      new Cloud_News__e(
        Urgent__c = true,
        Location__c = 'Tokyo',
        News_Content__c = 'Test news content'
      )
    );
    events.add(
      new Cloud_News__e(
        Urgent__c = false,
        Location__c = 'Osaka',
        News_Content__c = 'Another news'
      )
    );

    // 模拟队列存在
    Group testQueue = new Group(
      Name = 'News Queue',
      DeveloperName = 'News_Queue',
      Type = 'Queue'
    );
    insert testQueue;

    Test.startTest();
    CloudNewsService.createCasesFromEvents(events);
    Test.stopTest();

    // 验证案例创建
    List<Case> cases = [
      SELECT Id, Priority, Subject, OwnerId, Description
      FROM Case
    ];
    System.assertEquals(2, cases.size(), '应创建两个案例');

    // 验证第一个案例
    Case case1 = cases[0];
    System.assertEquals('High', case1.Priority);
    System.assertEquals('News team dispatch to Tokyo', case1.Subject);
    System.assertEquals(testQueue.Id, case1.OwnerId);
    System.assertEquals('Test news content', case1.Description);
  }

  @IsTest
  static void testCreateCasesFromEventsNoQueue() {
    // 确保没有队列
    List<Group> existingQueues = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'News_Queue'
    ];
    if (!existingQueues.isEmpty()) {
      delete existingQueues;
    }

    List<Cloud_News__e> events = new List<Cloud_News__e>();
    events.add(
      new Cloud_News__e(
        Urgent__c = true,
        Location__c = 'Tokyo',
        News_Content__c = 'Test'
      )
    );

    Test.startTest();
    CloudNewsService.createCasesFromEvents(events);
    Test.stopTest();

    List<Case> cases = [SELECT Id FROM Case];
    System.assertEquals(0, cases.size(), '没有队列时应无案例创建');
  }
}
