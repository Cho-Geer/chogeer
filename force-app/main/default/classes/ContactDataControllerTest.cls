@IsTest
private class ContactDataControllerTest {
  @IsTest
  static void saveContactsForAccountBindsEveryContactToTargetAccount() {
    Account targetAccount = new Account(Name = 'Bulk Target Account');
    Account differentAccount = new Account(Name = 'Different Account');
    insert new List<Account>{ targetAccount, differentAccount };

    List<Contact> requestContacts = new List<Contact>{
      new Contact(
        FirstName = 'First',
        LastName = 'Bulk Target One',
        AccountId = differentAccount.Id
      ),
      new Contact(
        FirstName = 'Second',
        LastName = 'Bulk Target Two',
        AccountId = differentAccount.Id
      )
    };

    Test.startTest();
    ContactDataController.ReturnValue result =
      ContactDataController.saveContactsForAccount(
        targetAccount.Id,
        requestContacts
      );
    Test.stopTest();

    System.assertEquals(true, result.isSuccess, result.message);
    System.assertEquals(2, result.dataList.size());

    List<Contact> createdContacts = [
      SELECT FirstName, LastName, AccountId
      FROM Contact
      WHERE LastName IN ('Bulk Target One', 'Bulk Target Two')
    ];
    System.assertEquals(2, createdContacts.size());
    for (Contact createdContact : createdContacts) {
      System.assertEquals(targetAccount.Id, createdContact.AccountId);
    }
  }

  @IsTest
  static void saveContactsKeepsExistingTabBehavior() {
    Account selectedAccount = new Account(Name = 'Existing Tab Account');
    insert selectedAccount;

    Test.startTest();
    ContactDataController.ReturnValue result = ContactDataController.saveContacts(
      new List<Contact>{
        new Contact(
          FirstName = 'Existing',
          LastName = 'Tab Contact',
          AccountId = selectedAccount.Id
        )
      }
    );
    Test.stopTest();

    System.assertEquals(true, result.isSuccess, result.message);
    Contact createdContact = [
      SELECT AccountId
      FROM Contact
      WHERE LastName = 'Tab Contact'
      LIMIT 1
    ];
    System.assertEquals(selectedAccount.Id, createdContact.AccountId);
  }

  @IsTest
  static void saveContactsForAccountRejectsMissingAccount() {
    Test.startTest();
    ContactDataController.ReturnValue result =
      ContactDataController.saveContactsForAccount(
        null,
        new List<Contact>{ new Contact(LastName = 'Invalid Target') }
      );
    Test.stopTest();

    System.assertEquals(false, result.isSuccess);
    System.assert(result.message.contains('取引先を指定してください。'));
  }
}
