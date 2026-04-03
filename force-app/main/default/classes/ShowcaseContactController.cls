public with sharing class ShowcaseContactController {
  public class ContactSummary {
    @AuraEnabled
    public Id contactId;
    @AuraEnabled
    public String firstName;
    @AuraEnabled
    public String lastName;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String accountName;

    public ContactSummary(Contact contactRecord) {
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

  @AuraEnabled(cacheable=true)
  public static List<ContactSummary> getRecentContacts() {
    List<Contact> queriedContacts = [
      SELECT Id, FirstName, LastName, Email, Title, Account.Name
      FROM Contact
      ORDER BY LastModifiedDate DESC
      LIMIT 10
    ];

    SObjectAccessDecision accessDecision = Security.stripInaccessible(
      AccessType.READABLE,
      queriedContacts
    );

    List<ContactSummary> results = new List<ContactSummary>();
    for (SObject accessibleRecord : accessDecision.getRecords()) {
      results.add(new ContactSummary((Contact) accessibleRecord));
    }
    return results;
  }

  @AuraEnabled
  public static Id createContact(
    String firstName,
    String lastName,
    String email,
    String title
  ) {
    if (String.isBlank(lastName)) {
      throw new AuraHandledException('Last name is required.');
    }

    Contact contactRecord = new Contact(
      FirstName = normalizeValue(firstName),
      LastName = normalizeValue(lastName),
      Email = normalizeValue(email),
      Title = normalizeValue(title)
    );
    insert contactRecord;

    return contactRecord.Id;
  }

  private static String normalizeValue(String input) {
    return String.isBlank(input) ? null : input.trim();
  }
}
