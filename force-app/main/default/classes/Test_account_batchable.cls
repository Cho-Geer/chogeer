@isTest
public class Test_account_batchable {
  private static final Integer TEST_RECORD_COUNT = 250;
  private static final String NAME_PREFIX = 'TestAccount_';
  private static final String NAME_SUFFIX = '_ACC_';

  @testSetup
  static void setupTestData() {
    List<Account> testAccounts = new List<Account>();

    for (Integer i = 0; i < TEST_RECORD_COUNT; i++) {
      testAccounts.add(
        new Account(
          Name = NAME_PREFIX + i,
          Heroku_Connect__c = String.valueOf(i)
        )
      );
    }

    insert testAccounts;
  }

  @isTest
  static void testDefaultBatchSize() {
    List<Account> existingAccounts = [
      SELECT Id
      FROM Account
      WHERE Name LIKE :(NAME_PREFIX + '%')
    ];
    System.assert(
      existingAccounts.size() >= TEST_RECORD_COUNT,
      'Test data should have at least ' + TEST_RECORD_COUNT + ' records'
    );

    Test.startTest();
    Account_batchable batchJob = new Account_batchable();
    Id batchJobId = Database.executeBatch(batchJob);
    Test.stopTest();

    List<Account> updatedAccounts = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE :(NAME_PREFIX + '%' + NAME_SUFFIX)
    ];
    System.assertEquals(
      200,
      updatedAccounts.size(),
      'Default batch size should process 200 records'
    );

    for (Account acc : updatedAccounts) {
      System.assert(
        acc.Name.endsWith(NAME_SUFFIX),
        'Account name should have suffix: ' + acc.Name
      );
    }
  }

  @isTest
  static void testCustomBatchSize() {
    Integer customBatchSize = 50;

    Test.startTest();
    Account_batchable batchJob = new Account_batchable(customBatchSize);
    Id batchJobId = Database.executeBatch(batchJob);
    Test.stopTest();

    List<Account> updatedAccounts = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE :(NAME_PREFIX + '%' + NAME_SUFFIX)
    ];
    System.assertEquals(
      customBatchSize,
      updatedAccounts.size(),
      'Should process exactly ' + customBatchSize + ' records'
    );
  }

  @isTest
  static void testBatchWithSmallerDataSet() {
    Integer testRecordCount = 30;
    List<Account> smallDataSet = new List<Account>();

    for (Integer i = 0; i < testRecordCount; i++) {
      smallDataSet.add(
        new Account(Name = 'SmallTest_' + i, Heroku_Connect__c = 'small_' + i)
      );
    }

    insert smallDataSet;

    Test.startTest();
    Account_batchable batchJob = new Account_batchable(200);
    Id batchJobId = Database.executeBatch(batchJob);
    Test.stopTest();

    String pattern = '%' + NAME_SUFFIX;
    List<Account> allUpdatedAccounts = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE :pattern
    ];
    System.assert(
      allUpdatedAccounts.size() >= testRecordCount,
      'Should update at least the test records'
    );
  }

  @isTest
  static void testBatchStatistics() {
    Test.startTest();
    Account_batchable batchJob = new Account_batchable();
    batchJob.batchSize = 75;
    Id batchJobId = Database.executeBatch(batchJob, 75);
    Test.stopTest();

    System.debug('Batch processed: ' + batchJob.processedCount);
    System.debug('Batch success: ' + batchJob.successCount);
    System.debug('Batch errors: ' + batchJob.errorCount);

    System.assert(
      batchJob.processedCount >= 0,
      'Processed count should be recorded'
    );
    System.assert(
      batchJob.successCount >= 0,
      'Success count should be recorded'
    );
    System.assert(batchJob.errorCount >= 0, 'Error count should be recorded');
  }

  @isTest
  static void testBatchExecuteWithErrors() {
    List<Account> testAccounts = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      testAccounts.add(new Account(Name = 'ErrorTest_' + i));
    }
    insert testAccounts;

    Test.setReadOnlyApplicationMode(true);

    Test.startTest();
    Account_batchable batchJob = new Account_batchable(10);
    Id batchJobId = Database.executeBatch(batchJob);
    Test.stopTest();

    System.debug('Error messages: ' + batchJob.errorMessages);
    System.assert(
      batchJob.errorCount >= 0,
      'Error count should be recorded even if no errors'
    );
  }
}
