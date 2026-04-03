@IsTest
private class OrderEventTriggerTest {
  @IsTest
  static void createsTaskForShippedOrdersOnly() {
    Order_Event__e shippedEvent = new Order_Event__e(
      Has_Shipped__c = true,
      Order_Number__c = 'SO-1001'
    );
    Order_Event__e pendingEvent = new Order_Event__e(
      Has_Shipped__c = false,
      Order_Number__c = 'SO-1002'
    );

    Test.startTest();
    Database.SaveResult shippedResult = EventBus.publish(shippedEvent);
    Database.SaveResult pendingResult = EventBus.publish(pendingEvent);
    Test.stopTest();

    System.assertEquals(true, shippedResult.isSuccess());
    System.assertEquals(true, pendingResult.isSuccess());

    List<Task> createdTasks = [
      SELECT Subject, Status, Priority, Description
      FROM Task
      WHERE Subject LIKE 'Follow up on shipped order%'
    ];
    System.assertEquals(1, createdTasks.size());
    System.assertEquals(
      'Follow up on shipped order SO-1001',
      createdTasks[0].Subject
    );
    System.assertEquals('Not Started', createdTasks[0].Status);
  }
}
