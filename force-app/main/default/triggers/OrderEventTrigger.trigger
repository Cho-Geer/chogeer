trigger OrderEventTrigger on Order_Event__e(after insert) {
  List<Task> tasksToCreate = new List<Task>();

  for (Order_Event__e orderEvent : Trigger.New) {
    if (orderEvent.Has_Shipped__c == true) {
      tasksToCreate.add(
        new Task(
          Subject = 'Follow up on shipped order ' + orderEvent.Order_Number__c,
          Status = 'Not Started',
          Priority = 'Normal',
          OwnerId = UserInfo.getUserId(),
          Description = 'Created from the Order_Event__e platform event showcase.'
        )
      );
    }
  }

  if (!tasksToCreate.isEmpty()) {
    insert tasksToCreate;
  }
}
