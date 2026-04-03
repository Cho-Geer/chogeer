@IsTest
private class ShowcaseContactControllerTest {
  @IsTest
  static void returnsRecentContacts() {
    Account accountRecord = new Account(Name = 'Customer Platform');
    insert accountRecord;

    insert new Contact(
      FirstName = 'Mina',
      LastName = 'Chen',
      Email = 'mina.chen@example.com',
      Title = 'Platform Engineer',
      AccountId = accountRecord.Id
    );

    Test.startTest();
    List<ShowcaseContactController.ContactSummary> results = ShowcaseContactController.getRecentContacts();
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals('Mina', results[0].firstName);
    System.assertEquals('Customer Platform', results[0].accountName);
  }

  @IsTest
  static void createsContactFromUiInputs() {
    Test.startTest();
    Id contactId = ShowcaseContactController.createContact(
      'Noa',
      'Wang',
      'noa.wang@example.com',
      'Solution Architect'
    );
    Test.stopTest();

    Contact createdContact = [
      SELECT FirstName, LastName, Email, Title
      FROM Contact
      WHERE Id = :contactId
    ];
    System.assertEquals('Noa', createdContact.FirstName);
    System.assertEquals('Wang', createdContact.LastName);
    System.assertEquals('noa.wang@example.com', createdContact.Email);
    System.assertEquals('Solution Architect', createdContact.Title);
  }

  @IsTest
  static void requiresLastNameWhenCreatingContact() {
    Boolean didThrow = false;
    try {
      ShowcaseContactController.createContact('Noa', null, null, null);
    } catch (AuraHandledException ex) {
      didThrow = true;
    }
    System.assertEquals(true, didThrow, 'Expected an AuraHandledException.');
  }
}
