@IsTest
private with sharing class ShowcaseContactControllerPaginationTest {
  @TestSetup
  static void setupTestData() {
    Account testAccount = new Account(Name = 'Pagination Test Account');
    insert testAccount;

    insert new List<Contact>{
      new Contact(
        FirstName = 'Page',
        LastName = 'One',
        AccountId = testAccount.Id
      ),
      new Contact(
        FirstName = 'Page',
        LastName = 'Two',
        AccountId = testAccount.Id
      ),
      new Contact(
        FirstName = 'Page',
        LastName = 'Three',
        AccountId = testAccount.Id
      )
    };
  }

  @IsTest
  static void returnsContactsByPageForAccount() {
    Id accountId = [
      SELECT Id
      FROM Account
      WHERE Name = 'Pagination Test Account'
      LIMIT 1
    ].Id;

    Test.startTest();
    ShowcaseContactController.PaginatedResult firstPage = ShowcaseContactController.getContactsByAccountPage(
      accountId,
      1,
      2
    );
    ShowcaseContactController.PaginatedResult secondPage = ShowcaseContactController.getContactsByAccountPage(
      accountId,
      2,
      2
    );
    Test.stopTest();

    System.assertEquals(3, firstPage.totalRecords);
    System.assertEquals(2, firstPage.totalPages);
    System.assertEquals(2, firstPage.records.size());
    System.assertEquals(1, secondPage.records.size());
    for (ShowcaseContactController.ContactSummary summary : firstPage.records) {
      System.assertEquals('Pagination Test Account', summary.accountName);
    }
  }

  @IsTest
  static void returnsEmptyResultWithoutAccount() {
    Test.startTest();
    ShowcaseContactController.PaginatedResult result = ShowcaseContactController.getContactsByAccountPage(
      null,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(1, result.pageNumber);
    System.assertEquals(
      ShowcaseContactController.DEFAULT_PAGE_SIZE,
      result.pageSize
    );
    System.assertEquals(0, result.totalRecords);
    System.assertEquals(0, result.records.size());
  }
}
