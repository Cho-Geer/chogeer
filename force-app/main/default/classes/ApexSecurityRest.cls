@RestResource(urlMapping='/apexSecurityRest')
global with sharing class ApexSecurityRest {
  @HttpGet
  global static Contact doGet() {
    Id recordId = RestContext.request.params?.get('id');
    Contact result;
    List<Contact> results = [
      SELECT id, Name, Title, Description, Account.Name
      FROM Contact
      WHERE Id = :recordId
      WITH SECURITY_ENFORCED
    ];
    SObjectAccessDecision securityDecision = Security.stripInaccessible(
      AccessType.READABLE,
      results
    );
    if (!securityDecision.getRecords().isEmpty()) {
      result = (Contact) securityDecision.getRecords()[0];
      SObjectAccessDecision updateDecision = Security.stripInaccessible(
        AccessType.UPDATABLE,
        results
      );
      if (
        !updateDecision.getRemovedFields().isEmpty() &&
        updateDecision.getRemovedFields().values()[0].contains('Description')
      ) {
        result.Description = result.Account?.Name;
      }
    }
    return result;
  }
  public class FunctionalException extends Exception {
  }
  public class SecurityException extends Exception {
  }
}
