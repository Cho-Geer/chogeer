public with sharing class Account_batchable implements Database.Batchable<SObject>, Database.Stateful {
  public Integer batchSize = 200;
  public Integer processedCount = 0;
  public Integer successCount = 0;
  public Integer errorCount = 0;
  public List<String> errorMessages = new List<String>();

  public Account_batchable() {
  }

  public Account_batchable(Integer batchSize) {
    if (batchSize != null && batchSize > 0) {
      this.batchSize = batchSize;
    }
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    try {
      // Check CRUD/FLS permissions before query
      if (!Schema.SObjectType.Account.isAccessible()) {
        throw new BatchableException(
          'ユーザーに取引先の参照権限がありません。'
        );
      }
      return Database.getQueryLocator(
        [
          SELECT Id, Name
          FROM Account
          LIMIT :batchSize
        ]
      );
    } catch (Exception e) {
      System.debug(
        'Account_batchable.start error: ' +
          e.getMessage() +
          ' ' +
          e.getStackTraceString()
      );
      throw e;
    }
  }

  public void execute(Database.BatchableContext bc, List<Account> scope) {
    List<Account> accountsToUpdate = new List<Account>();
    List<Database.SaveResult> saveResults;

    try {
      // Check CRUD/FLS permissions before update
      if (!Schema.SObjectType.Account.isUpdateable()) {
        throw new BatchableException(
          'ユーザーに取引先の更新権限がありません。'
        );
      }

      for (Account acc : scope) {
        Account updatedAcc = acc.clone(true, true, true, true);
        updatedAcc.Name = acc.Name + '_ACC_';
        accountsToUpdate.add(updatedAcc);
      }

      if (!accountsToUpdate.isEmpty()) {
        // Apply FLS (Field Level Security) checks for update operation
        SObjectAccessDecision securityDecision = Security.stripInaccessible(
          AccessType.UPDATABLE,
          accountsToUpdate
        );
        saveResults = Database.update(securityDecision.getRecords(), false);

        for (Integer i = 0; i < saveResults.size(); i++) {
          Database.SaveResult sr = saveResults[i];
          if (sr.isSuccess()) {
            successCount++;
          } else {
            errorCount++;
            String errorMsg = 'Account Id: ' + accountsToUpdate[i].Id + ' - ';
            for (Database.Error err : sr.getErrors()) {
              errorMsg += err.getMessage() + ' ';
            }
            errorMessages.add(errorMsg);
          }
        }
        processedCount += accountsToUpdate.size();
      }
    } catch (Exception e) {
      errorCount += scope.size();
      errorMessages.add(
        'Execute batch error: ' + e.getMessage() + ' ' + e.getStackTraceString()
      );
      System.debug(
        'Account_batchable.execute error: ' +
          e.getMessage() +
          ' ' +
          e.getStackTraceString()
      );
    }
  }

  public void finish(Database.BatchableContext bc) {
    try {
      System.debug(
        'Account_batchable finished. Processed: ' +
          processedCount +
          ', Success: ' +
          successCount +
          ', Errors: ' +
          errorCount
      );

      if (!errorMessages.isEmpty()) {
        System.debug('Error details: ' + String.join(errorMessages, '; '));
      }
    } catch (Exception e) {
      System.debug('Account_batchable.finish error: ' + e.getMessage());
    }
  }

  public class BatchableException extends Exception {
  }
}
