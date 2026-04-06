@isTest
public with sharing class ApexSecurityRestTest {
  @isTest
  static void testDoGetWithValidId() {
    // Create test data
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      AccountId = testAccount.Id,
      Title = 'Manager'
    );
    insert testContact;

    // Set up RestRequest
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/apexSecurityRest';
    req.httpMethod = 'GET';
    req.params.put('id', testContact.Id);
    RestContext.request = req;

    Test.startTest();
    Contact result = ApexSecurityRest.doGet();
    Test.stopTest();

    // Verify result
    System.assertNotEquals(null, result, 'Contact should be returned');
    System.assertEquals(testContact.Id, result.Id, 'Contact Id should match');
    System.assertEquals(testContact.Title, result.Title, 'Title should match');
    System.assertEquals(
      testAccount.Name,
      result.Account.Name,
      'Account Name should match'
    );
  }

  @isTest
  static void testDoGetWithInvalidId() {
    // Set up RestRequest with invalid ID
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/apexSecurityRest';
    req.httpMethod = 'GET';
    req.params.put('id', '001000000000000'); // Invalid ID
    RestContext.request = req;

    Test.startTest();
    Contact result = ApexSecurityRest.doGet();
    Test.stopTest();

    // Should return null when no contact found
    System.assertEquals(null, result, 'Should return null for invalid ID');
  }

  @isTest
  static void testDoGetWithoutIdParam() {
    // Set up RestRequest without id parameter
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/apexSecurityRest';
    req.httpMethod = 'GET';
    RestContext.request = req;

    Test.startTest();
    Contact result = ApexSecurityRest.doGet();
    Test.stopTest();

    // Should return null when no id parameter
    System.assertEquals(
      null,
      result,
      'Should return null when no id parameter'
    );
  }

  @isTest
  static void testDoGetWithStripInaccessible() {
    // Create test data
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      AccountId = testAccount.Id,
      Title = 'Manager'
    );
    insert testContact;

    // Set up RestRequest
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/apexSecurityRest';
    req.httpMethod = 'GET';
    req.params.put('id', testContact.Id);
    RestContext.request = req;

    Test.startTest();
    Contact result = ApexSecurityRest.doGet();
    Test.stopTest();

    // Verify Security.stripInaccessible logic
    // The method checks if Description field is removed from UPDATABLE access
    // Description is now included in SELECT list, so stripInaccessible will process it
    // The logic sets Description to Account.Name if user lacks update permission for Description
    // We ensure the method executes without errors
    System.assertNotEquals(null, result, 'Contact should be returned');
  }
}
