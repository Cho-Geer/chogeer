trigger CloudNewsTrigger on Cloud_News__e(after insert) {
  CloudNewsService.createCasesFromEvents(Trigger.new);
}
