@IsTest
private class ShowcaseContactRestResourceTest {
  @IsTest
  static void returnsContactWhenIdIsPresent() {
    Account accountRecord = new Account(Name = 'Showcase Account');
    insert accountRecord;

    Contact contactRecord = new Contact(
      FirstName = 'Ava',
      LastName = 'Li',
      Email = 'ava.li@example.com',
      Title = 'Integration Lead',
      AccountId = accountRecord.Id
    );
    insert contactRecord;

    RestRequest request = new RestRequest();
    request.requestUri = '/services/apexrest/showcase/contacts';
    request.httpMethod = 'GET';
    request.addParameter('id', contactRecord.Id);
    RestContext.request = request;
    RestContext.response = new RestResponse();

    ShowcaseContactRestResource.ContactResponse result = ShowcaseContactRestResource.getContact();

    System.assertNotEquals(null, result);
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(contactRecord.Id, result.contactId);
    System.assertEquals('Ava', result.firstName);
    System.assertEquals('Li', result.lastName);
    System.assertEquals('Showcase Account', result.accountName);
  }

  @IsTest
  static void returnsBadRequestWhenIdIsMissing() {
    RestRequest request = new RestRequest();
    request.requestUri = '/services/apexrest/showcase/contacts';
    request.httpMethod = 'GET';
    RestContext.request = request;
    RestContext.response = new RestResponse();

    ShowcaseContactRestResource.ContactResponse result = ShowcaseContactRestResource.getContact();

    System.assertEquals(null, result);
    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void returnsNotFoundWhenRecordIsMissing() {
    RestRequest request = new RestRequest();
    request.requestUri = '/services/apexrest/showcase/contacts';
    request.httpMethod = 'GET';
    request.addParameter('id', '003000000000000AAA');
    RestContext.request = request;
    RestContext.response = new RestResponse();

    ShowcaseContactRestResource.ContactResponse result = ShowcaseContactRestResource.getContact();

    System.assertEquals(null, result);
    System.assertEquals(404, RestContext.response.statusCode);
  }

  @IsTest
  static void returnsBadRequestWhenIdFormatIsInvalid() {
    RestRequest request = new RestRequest();
    request.requestUri = '/services/apexrest/showcase/contacts';
    request.httpMethod = 'GET';
    request.addParameter('id', 'not-a-salesforce-id');
    RestContext.request = request;
    RestContext.response = new RestResponse();

    ShowcaseContactRestResource.ContactResponse result = ShowcaseContactRestResource.getContact();

    System.assertEquals(null, result);
    System.assertEquals(400, RestContext.response.statusCode);
  }
}
