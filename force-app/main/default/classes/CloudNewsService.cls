public with sharing class CloudNewsService {
  public static void createCasesFromEvents(List<Cloud_News__e> events) {
    List<Case> cases = new List<Case>();
    Id queueId = getNewsQueueId();

    if (queueId == null) {
      System.debug('News queue not found');
      return;
    }

    for (Cloud_News__e event : events) {
      Case cs = new Case(
        Priority = event.Urgent__c ? 'High' : 'Medium',
        Subject = 'News team dispatch to ' + event.Location__c,
        OwnerId = queueId,
        Description = event.News_Content__c
      );
      cases.add(cs);
    }

    if (!cases.isEmpty()) {
      SObjectAccessDecision decision = Security.stripInaccessible(
        AccessType.CREATABLE,
        cases
      );
      insert decision.getRecords();
    }
  }

  private static Id getNewsQueueId() {
    List<Group> queues = [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = 'News_Queue'
      WITH SECURITY_ENFORCED
    ];
    return queues.isEmpty() ? null : queues[0].Id;
  }
}
