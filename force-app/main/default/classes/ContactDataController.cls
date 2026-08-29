public with sharing class ContactDataController {
  private static final Integer ACCOUNT_PAGE_SIZE = 25;

  @AuraEnabled
  public static ReturnValue getAccountForLookup(
    String searchStr,
    String lastAccountName,
    Id lastAccountId
  ) {
    ReturnValue rt = new ReturnValue();
    try {
      // Check CRUD/FLS permissions before query
      if (!Schema.SObjectType.Account.isAccessible()) {
        throw new AuraHandledException(
          'ユーザーに取引先の参照権限がありません。'
        );
      }
      String normalizedSearch = String.isBlank(searchStr)
        ? null
        : searchStr.trim();
      String searchPattern = normalizedSearch == null
        ? null
        : '%' + normalizedSearch + '%';
      Boolean hasCursor =
        String.isNotBlank(lastAccountName) && lastAccountId != null;
      Integer queryLimit = ACCOUNT_PAGE_SIZE + 1;
      List<Account> accountList;

      // Keyset pagination keeps loading reliable even when an org has more
      // than Salesforce's OFFSET limit. The Id tie-breaker handles duplicate
      // Account names without skipping or repeating records.
      if (String.isBlank(normalizedSearch) && !hasCursor) {
        accountList = [
          SELECT Id, Name
          FROM Account
          WITH SECURITY_ENFORCED
          ORDER BY Name ASC, Id ASC
          LIMIT :queryLimit
        ];
      } else if (String.isBlank(normalizedSearch)) {
        accountList = [
          SELECT Id, Name
          FROM Account
          WHERE
            (Name > :lastAccountName
            OR (Name = :lastAccountName AND Id > :lastAccountId))
          WITH SECURITY_ENFORCED
          ORDER BY Name ASC, Id ASC
          LIMIT :queryLimit
        ];
      } else if (!hasCursor) {
        accountList = [
          SELECT Id, Name
          FROM Account
          WHERE Name LIKE :searchPattern
          WITH SECURITY_ENFORCED
          ORDER BY Name ASC, Id ASC
          LIMIT :queryLimit
        ];
      } else {
        accountList = [
          SELECT Id, Name
          FROM Account
          WHERE
            Name LIKE :searchPattern
            AND (Name > :lastAccountName
            OR (Name = :lastAccountName AND Id > :lastAccountId))
          WITH SECURITY_ENFORCED
          ORDER BY Name ASC, Id ASC
          LIMIT :queryLimit
        ];
      }

      Boolean hasMore = accountList.size() > ACCOUNT_PAGE_SIZE;
      if (hasMore) {
        accountList.remove(accountList.size() - 1);
      }
      // Apply FLS (Field Level Security) checks
      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.READABLE,
        accountList
      );
      rt.isSuccess = true;
      rt.message = '';
      rt.dataList = securityDecision.getRecords();
      rt.hasMore = hasMore;
    } catch (Exception e) {
      rt.isSuccess = false;
      rt.message = 'アカウント取得エラー: ' + e.getMessage();
      System.debug(
        'ContactDataController.getAccountForLookup error: ' +
        e.getStackTraceString()
      );
    }
    return rt;
  }

  @AuraEnabled
  public static ReturnValue getRecordType() {
    ReturnValue rt = new ReturnValue();
    try {
      // Check object permission before reading the Contact record type metadata.
      if (!Schema.SObjectType.Contact.isAccessible()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の参照権限がありません。'
        );
      }
      // SOQL does not return the implicit Master record type when no custom
      // Contact record types exist. Schema metadata includes all record types
      // available to the current user, including Master.
      List<RecordType> recordTypeList = new List<RecordType>();
      for (
        Schema.RecordTypeInfo recordTypeInfo : Schema.SObjectType.Contact.getRecordTypeInfos()
      ) {
        if (recordTypeInfo.isActive() && recordTypeInfo.isAvailable()) {
          recordTypeList.add(
            new RecordType(
              Id = recordTypeInfo.getRecordTypeId(),
              Name = recordTypeInfo.getName()
            )
          );
        }
      }
      rt.isSuccess = true;
      rt.message = '';
      rt.dataList = recordTypeList;
    } catch (Exception e) {
      rt.isSuccess = false;
      rt.message = 'レコードタイプ取得エラー: ' + e.getMessage();
      System.debug(
        'ContactDataController.getRecordType error: ' + e.getStackTraceString()
      );
    }
    return rt;
  }

  @AuraEnabled
  public static ReturnValue getContactList() {
    ReturnValue returnValue = new ReturnValue();
    try {
      // Check CRUD/FLS permissions before query
      if (!Schema.SObjectType.Contact.isAccessible()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の参照権限がありません。'
        );
      }
      List<Contact> contactList = [
        SELECT
          Id,
          LastName,
          FirstName,
          HasOptedOutOfEmail,
          Level__c,
          LastCUUpdateDate
        FROM Contact
        WITH SECURITY_ENFORCED
        ORDER BY LastName DESC
        LIMIT 1000
      ];
      // Apply FLS (Field Level Security) checks
      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.READABLE,
        contactList
      );
      returnValue.isSuccess = true;
      returnValue.message = '取得しました';
      returnValue.dataList = securityDecision.getRecords();
    } catch (Exception e) {
      returnValue.isSuccess = false;
      returnValue.message = '取引先責任者取得エラー: ' + e.getMessage();
      System.debug(
        'ContactDataController.getContactList error: ' + e.getStackTraceString()
      );
    }
    return returnValue;
  }

  @AuraEnabled
  public static ReturnValue searchContactList(String searchStr) {
    ReturnValue rt = new ReturnValue();
    try {
      // Check CRUD/FLS permissions before query
      if (!Schema.SObjectType.Contact.isAccessible()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の参照権限がありません。'
        );
      }
      List<Contact> contactList;
      if (String.isEmpty(searchStr) || searchStr == '*') {
        contactList = [
          SELECT LastName, FirstName, HasOptedOutOfEmail, Level__c
          FROM Contact
          WITH SECURITY_ENFORCED
          ORDER BY LastName DESC
          LIMIT 1000
        ];
      } else {
        String searchPattern = '%' + searchStr + '%';
        contactList = [
          SELECT Id, LastName, FirstName, HasOptedOutOfEmail, Level__c
          FROM Contact
          WHERE LastName LIKE :searchPattern
          WITH SECURITY_ENFORCED
          ORDER BY LastName DESC
          LIMIT 1000
        ];
      }
      // Apply FLS (Field Level Security) checks
      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.READABLE,
        contactList
      );
      rt.isSuccess = true;
      rt.dataList = securityDecision.getRecords();
    } catch (Exception e) {
      rt.isSuccess = false;
      rt.message = '検索エラー: ' + e.getMessage();
      System.debug(
        'ContactDataController.searchContactList error: ' +
        e.getStackTraceString()
      );
    }
    return rt;
  }

  @AuraEnabled
  public static ReturnValue saveContacts(List<Contact> contactList) {
    ReturnValue returnValue = new ReturnValue();
    try {
      // Check CRUD/FLS permissions before insert
      if (!Schema.SObjectType.Contact.isCreateable()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の作成権限がありません。'
        );
      }
      List<Contact> contactsToInsert = new List<Contact>();
      for (Contact con : contactList) {
        Contact newContact = con.clone(false, false, false, false);
        newContact.AccountId = con.AccountId;
        contactsToInsert.add(newContact);
      }
      // Apply FLS (Field Level Security) checks for create operation
      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.CREATABLE,
        contactsToInsert
      );
      insert securityDecision.getRecords();
      returnValue.isSuccess = true;
      returnValue.dataList = securityDecision.getRecords();
      returnValue.message =
        securityDecision.getRecords().size() +
        '件の取引先責任者を作成しました。';
    } catch (DmlException e) {
      returnValue.isSuccess = false;
      returnValue.message = 'データ登録エラー: ' + e.getDmlMessage(0);
      System.debug(
        'ContactDataController.saveContacts DML error: ' + e.getMessage()
      );
    } catch (Exception e) {
      returnValue.isSuccess = false;
      returnValue.message = 'システムエラー: ' + e.getMessage();
      System.debug(
        'ContactDataController.saveContacts error: ' + e.getStackTraceString()
      );
    }
    return returnValue;
  }

  @AuraEnabled
  public static ReturnValue saveContactsForAccount(
    Id accountId,
    List<Contact> contactList
  ) {
    ReturnValue returnValue = new ReturnValue();
    try {
      if (accountId == null) {
        returnValue.isSuccess = false;
        returnValue.message = '取引先を指定してください。';
        return returnValue;
      }
      if (!Schema.SObjectType.Account.isAccessible()) {
        throw new AuraHandledException(
          'ユーザーに取引先の参照権限がありません。'
        );
      }
      if (!Schema.SObjectType.Contact.isCreateable()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の作成権限がありません。'
        );
      }
      if (!Schema.SObjectType.Contact.fields.AccountId.isCreateable()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の取引先項目を書き込む権限がありません。'
        );
      }

      // with sharing plus SECURITY_ENFORCED ensures that the current user can
      // access the target Account before any Contact is inserted.
      Account targetAccount = [
        SELECT Id
        FROM Account
        WHERE Id = :accountId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];

      List<Contact> contactsToInsert = new List<Contact>();
      for (Contact con : contactList) {
        Contact newContact = con.clone(false, false, false, false);
        // Never trust the AccountId supplied by the client payload.
        newContact.AccountId = accountId;
        contactsToInsert.add(newContact);
      }

      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.CREATABLE,
        contactsToInsert
      );
      insert securityDecision.getRecords();
      returnValue.isSuccess = true;
      returnValue.dataList = securityDecision.getRecords();
      returnValue.message =
        securityDecision.getRecords().size() +
        '件の取引先責任者を作成しました。';
    } catch (DmlException e) {
      returnValue.isSuccess = false;
      returnValue.message = 'データ登録エラー: ' + e.getDmlMessage(0);
      System.debug(
        'ContactDataController.saveContactsForAccount DML error: ' +
        e.getMessage()
      );
    } catch (Exception e) {
      returnValue.isSuccess = false;
      returnValue.message = 'システムエラー: ' + e.getMessage();
      System.debug(
        'ContactDataController.saveContactsForAccount error: ' +
        e.getStackTraceString()
      );
    }
    return returnValue;
  }

  @AuraEnabled
  public static ReturnValue deleteRow(Id id) {
    ReturnValue rv = new ReturnValue();
    try {
      // Check CRUD/FLS permissions before query and delete
      if (!Schema.SObjectType.Contact.isAccessible()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の参照権限がありません。'
        );
      }
      if (!Schema.SObjectType.Contact.isDeletable()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の削除権限がありません。'
        );
      }
      Contact contact = [
        SELECT Id
        FROM Contact
        WHERE Id = :id
        WITH SECURITY_ENFORCED
      ];
      Database.delete(contact, false, AccessLevel.USER_MODE);
      rv.isSuccess = true;
      rv.message = '正常に削除しました。';
    } catch (DmlException e) {
      rv.isSuccess = false;
      rv.message = '削除エラー: ' + e.getDmlMessage(0);
    } catch (Exception e) {
      rv.isSuccess = false;
      rv.message = 'システムエラー: ' + e.getMessage();
    }
    return rv;
  }

  @AuraEnabled
  public static ReturnValue updateContactRecord(Id id, Boolean flg) {
    ReturnValue rv = new ReturnValue();
    try {
      // Check CRUD/FLS permissions before query and update
      if (!Schema.SObjectType.Contact.isAccessible()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の参照権限がありません。'
        );
      }
      if (!Schema.SObjectType.Contact.isUpdateable()) {
        throw new AuraHandledException(
          'ユーザーに取引先責任者の更新権限がありません。'
        );
      }
      Contact contact = [
        SELECT Id, HasOptedOutOfEmail
        FROM Contact
        WHERE Id = :id
        WITH SECURITY_ENFORCED
      ];
      contact.HasOptedOutOfEmail = !flg;
      // Apply FLS (Field Level Security) checks for update operation
      SObjectAccessDecision securityDecision = Security.stripInaccessible(
        AccessType.UPDATABLE,
        new List<Contact>{ contact }
      );
      update securityDecision.getRecords();
      rv.isSuccess = true;
      rv.message = '正常に更新しました。';
    } catch (DmlException e) {
      rv.isSuccess = false;
      rv.message = '更新エラー: ' + e.getDmlMessage(0);
    } catch (Exception e) {
      rv.isSuccess = false;
      rv.message = 'システムエラー: ' + e.getMessage();
    }
    return rv;
  }

  public class ReturnValue {
    @AuraEnabled
    public Boolean isSuccess { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public List<Object> dataList { get; set; }

    @AuraEnabled
    public Boolean hasMore { get; set; }
  }
}
