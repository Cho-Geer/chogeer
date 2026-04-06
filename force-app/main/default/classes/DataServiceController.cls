public with sharing class DataServiceController {
  @AuraEnabled
  public static ReturnValue getContactList(String searchName) {
    ReturnValue rt = new ReturnValue();
    try {
      rt.isSuccess = true;
      rt.message = '';

      List<Contact> contacts;
      if (String.isEmpty(searchName) || searchName == '*') {
        contacts = [
          SELECT LastName, FirstName, Email, Phone
          FROM Contact
          WITH SECURITY_ENFORCED
          ORDER BY LastName
        ];
      } else {
        String searchPattern = searchName + '%';
        contacts = [
          SELECT LastName, FirstName, Email, Phone
          FROM Contact
          WHERE LastName LIKE :searchPattern
          WITH SECURITY_ENFORCED
          ORDER BY LastName
        ];
      }

      // Apply FLS (Field Level Security) checks
      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.READABLE,
        contacts
      );
      rt.contactList = securityDecision.getRecords();
    } catch (Exception e) {
      rt.isSuccess = false;
      rt.message = 'システムエラーが発生しました: ' + e.getMessage();
      System.debug(
        'DataServiceController.getContactList error: ' + e.getStackTraceString()
      );
    }
    return rt;
  }

  @AuraEnabled
  public static ReturnValue createContactList(List<Contact> contactList) {
    ReturnValue returnValue = new ReturnValue();
    try {
      List<Contact> contactsToInsert = new List<Contact>();
      for (Contact con : contactList) {
        Contact newContact = con.clone(false, false, false, false);
        newContact.AccountId = null;
        contactsToInsert.add(newContact);
      }

      // Check CRUD/FLS permissions before insert
      if (!Schema.SObjectType.Contact.isCreateable()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の作成権限がありません。'
        );
      }
      // Apply FLS (Field Level Security) checks for create operation
      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.CREATABLE,
        contactsToInsert
      );
      insert securityDecision.getRecords();
      returnValue.isSuccess = true;
      returnValue.message =
        '正常に' +
        contactsToInsert.size() +
        '件の取引先責任者を作成しました。';
    } catch (DmlException e) {
      returnValue.isSuccess = false;
      returnValue.message = 'データ登録エラー: ' + e.getDmlMessage(0);
      System.debug(
        'DataServiceController.createContactList DML error: ' + e.getMessage()
      );
    } catch (Exception e) {
      returnValue.isSuccess = false;
      returnValue.message = 'システムエラーが発生しました: ' + e.getMessage();
      System.debug(
        'DataServiceController.createContactList error: ' +
        e.getStackTraceString()
      );
    }
    return returnValue;
  }

  public class ReturnValue {
    @AuraEnabled
    public Boolean isSuccess { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public List<Contact> contactList { get; set; }
  }
}
