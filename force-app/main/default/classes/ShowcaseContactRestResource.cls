@RestResource(urlMapping='/showcase/contacts')
global with sharing class ShowcaseContactRestResource {
  global class ContactResponse {
    public Id contactId;
    public String firstName;
    public String lastName;
    public String email;
    public String title;
    public String accountName;

    public ContactResponse(Contact contactRecord) {
      contactId = contactRecord.Id;
      firstName = contactRecord.FirstName;
      lastName = contactRecord.LastName;
      email = contactRecord.Email;
      title = contactRecord.Title;
      accountName = contactRecord.Account != null
        ? contactRecord.Account.Name
        : null;
    }
  }

  @HttpGet
  global static ContactResponse getContact() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response != null
      ? RestContext.response
      : new RestResponse();
    RestContext.response = response;

    String rawId = request != null &&
      request.params != null
      ? request.params.get('id')
      : null;
    if (String.isBlank(rawId)) {
      response.statusCode = 400;
      return null;
    }

    Id contactId;
    try {
      contactId = (Id) rawId;
    } catch (Exception ex) {
      response.statusCode = 400;
      return null;
    }

    List<Contact> queriedContacts = [
      SELECT Id, FirstName, LastName, Email, Title, Account.Name
      FROM Contact
      WHERE Id = :contactId
      LIMIT 1
    ];

    SObjectAccessDecision accessDecision = Security.stripInaccessible(
      AccessType.READABLE,
      queriedContacts
    );
    List<SObject> accessibleRecords = accessDecision.getRecords();
    if (accessibleRecords.isEmpty()) {
      response.statusCode = 404;
      return null;
    }

    response.statusCode = 200;
    return new ContactResponse((Contact) accessibleRecords[0]);
  }
}
