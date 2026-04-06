public with sharing class ShowcaseContactController {
  // ========== 常量定义 ==========
  public static final Integer DEFAULT_PAGE_SIZE = 10;
  public static final Integer MAX_PAGE_SIZE = 100;
  public static final List<String> VALID_SORT_FIELDS = new List<String>{
    'LastName',
    'FirstName',
    'Email',
    'CreatedDate',
    'LastModifiedDate'
  };

  // ========== 数据类定义 ==========

  /**
   * @description 联系人摘要信息 - 用于UI展示
   */
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
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Datetime lastModifiedDate;

    public ContactSummary(Contact contactRecord) {
      contactId = contactRecord.Id;
      firstName = contactRecord.FirstName;
      lastName = contactRecord.LastName;
      email = contactRecord.Email;
      title = contactRecord.Title;
      accountName = contactRecord.Account != null
        ? contactRecord.Account.Name
        : null;
      status = determineContactStatus(contactRecord);
      lastModifiedDate = contactRecord.LastModifiedDate;
    }
  }

  /**
   * @description 分页查询结果
   */
  public class PaginatedResult {
    @AuraEnabled
    public List<ContactSummary> records;
    @AuraEnabled
    public Integer pageNumber;
    @AuraEnabled
    public Integer pageSize;
    @AuraEnabled
    public Integer totalRecords;
    @AuraEnabled
    public Integer totalPages;

    public PaginatedResult(
      List<ContactSummary> records,
      Integer pageNumber,
      Integer pageSize,
      Integer totalRecords
    ) {
      this.records = records;
      this.pageNumber = pageNumber;
      this.pageSize = pageSize;
      this.totalRecords = totalRecords;
      this.totalPages = totalRecords > 0
        ? (Integer) Math.ceil((Decimal) totalRecords / pageSize)
        : 0;
    }
  }

  /**
   * @description 查询过滤器
   */
  public class ContactFilter {
    @AuraEnabled
    public String searchTerm;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String accountId;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public Date createdAfter;
    @AuraEnabled
    public Date createdBefore;

    public Boolean hasFilters() {
      return String.isNotBlank(searchTerm) ||
        String.isNotBlank(status) ||
        String.isNotBlank(accountId) ||
        String.isNotBlank(title) ||
        createdAfter != null ||
        createdBefore != null;
    }
  }

  /**
   * @description 批量操作结果
   */
  public class BatchResult {
    @AuraEnabled
    public Integer totalRecords;
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public Integer failureCount;
    @AuraEnabled
    public List<String> errorMessages;

    public BatchResult(Integer totalRecords) {
      this.totalRecords = totalRecords;
      this.successCount = 0;
      this.failureCount = 0;
      this.errorMessages = new List<String>();
    }

    public void incrementSuccess() {
      successCount++;
    }

    public void incrementFailure(String errorMessage) {
      failureCount++;
      if (String.isNotBlank(errorMessage)) {
        errorMessages.add(errorMessage);
      }
    }
  }

  // ========== 异常类定义 ==========

  /**
   * @description 业务验证异常
   */
  public class ValidationException extends Exception {
  }

  /**
   * @description 数据访问异常
   */
  public class DataAccessException extends Exception {
  }

  @AuraEnabled(cacheable=true)
  public static List<ContactSummary> getRecentContacts() {
    List<Contact> queriedContacts = [
      SELECT Id, FirstName, LastName, Email, Title, Account.Name
      FROM Contact
      WITH SECURITY_ENFORCED
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
    SObjectAccessDecision decision = Security.stripInaccessible(
      AccessType.CREATABLE,
      new List<Contact>{ contactRecord }
    );
    insert decision.getRecords();

    return contactRecord.Id;
  }

  private static String normalizeValue(String input) {
    return String.isBlank(input) ? null : input.trim();
  }

  // ========== 辅助方法 ==========

  /**
   * @description 确定联系人状态
   */
  private static String determineContactStatus(Contact contact) {
    // 简单的状态逻辑示例
    // 实际业务中可以根据最后活动时间、邮箱验证状态等确定
    if (contact.Email == null) {
      return 'Incomplete';
    } else if (
      contact.LastModifiedDate != null &&
      contact.LastModifiedDate.date() == Date.today()
    ) {
      return 'Active';
    } else if (
      contact.CreatedDate != null &&
      contact.CreatedDate.date().daysBetween(Date.today()) <= 30
    ) {
      return 'New';
    } else {
      return 'Standard';
    }
  }

  /**
   * @description 构建动态SOQL查询
   */
  private static String buildContactQuery(
    ContactFilter filter,
    String sortField,
    String sortOrder
  ) {
    // 基础查询
    String query =
      'SELECT Id, FirstName, LastName, Email, Title, Account.Name, ' +
      'CreatedDate, LastModifiedDate ' +
      'FROM Contact ';

    // 添加WHERE条件
    List<String> conditions = new List<String>();

    if (filter != null && filter.hasFilters()) {
      if (String.isNotBlank(filter.searchTerm)) {
        String searchTerm =
          '%' +
          String.escapeSingleQuotes(filter.searchTerm) +
          '%';
        conditions.add(
          '(FirstName LIKE :searchTerm OR LastName LIKE :searchTerm OR Email LIKE :searchTerm)'
        );
      }

      if (String.isNotBlank(filter.status)) {
        // 状态过滤逻辑 - 这里简化处理
        // 实际业务中可能需要更复杂的逻辑
        if (filter.status == 'Active') {
          conditions.add('LastModifiedDate = TODAY');
        } else if (filter.status == 'New') {
          conditions.add('CreatedDate = LAST_N_DAYS:30');
        }
      }

      if (String.isNotBlank(filter.accountId)) {
        conditions.add('AccountId = :filter.accountId');
      }

      if (String.isNotBlank(filter.title)) {
        conditions.add('Title LIKE :filter.title');
      }

      if (filter.createdAfter != null) {
        conditions.add('CreatedDate >= :filter.createdAfter');
      }

      if (filter.createdBefore != null) {
        conditions.add('CreatedDate <= :filter.createdBefore');
      }
    }

    if (!conditions.isEmpty()) {
      query += ' WHERE ' + String.join(conditions, ' AND ');
    }

    // 添加排序
    String validatedSortField = validateSortField(sortField);
    String validatedSortOrder = (sortOrder == 'DESC') ? 'DESC' : 'ASC';
    query += ' ORDER BY ' + validatedSortField + ' ' + validatedSortOrder;

    return query;
  }

  /**
   * @description 验证排序字段
   */
  private static String validateSortField(String sortField) {
    if (String.isBlank(sortField) || !VALID_SORT_FIELDS.contains(sortField)) {
      return 'LastName'; // 默认排序字段
    }
    return sortField;
  }

  /**
   * @description 验证分页参数
   */
  private static void validatePaginationParams(
    Integer pageNumber,
    Integer pageSize
  ) {
    if (pageNumber == null || pageNumber < 1) {
      throw new ValidationException('Page number must be at least 1');
    }

    if (pageSize == null || pageSize < 1 || pageSize > MAX_PAGE_SIZE) {
      throw new ValidationException(
        'Page size must be between 1 and ' + MAX_PAGE_SIZE
      );
    }
  }

  // ========== 公共API方法 ==========

  /**
   * @description 分页获取联系人
   */
  @AuraEnabled(cacheable=true)
  public static PaginatedResult getContactsByPage(
    Integer pageNumber,
    Integer pageSize,
    ContactFilter filter,
    String sortField,
    String sortOrder
  ) {
    try {
      // 参数验证
      if (pageNumber == null)
        pageNumber = 1;
      if (pageSize == null)
        pageSize = DEFAULT_PAGE_SIZE;
      validatePaginationParams(pageNumber, pageSize);

      // 构建查询
      String query = buildContactQuery(filter, sortField, sortOrder);

      // 计算偏移量
      Integer offset = (pageNumber - 1) * pageSize;
      query += ' LIMIT :pageSize OFFSET :offset';

      // 执行查询（应用安全过滤）
      List<Contact> contacts = Database.query(query);
      SObjectAccessDecision accessDecision = Security.stripInaccessible(
        AccessType.READABLE,
        contacts
      );

      // 转换为摘要对象
      List<ContactSummary> summaries = new List<ContactSummary>();
      for (SObject accessibleRecord : accessDecision.getRecords()) {
        summaries.add(new ContactSummary((Contact) accessibleRecord));
      }

      // 获取总记录数（简化实现 - 实际中可能需要更高效的方法）
      String countQuery = buildContactQuery(filter, sortField, sortOrder);
      countQuery = 'SELECT COUNT() FROM (' + countQuery + ')';
      Integer totalRecords = Database.countQuery(countQuery);

      return new PaginatedResult(summaries, pageNumber, pageSize, totalRecords);
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Failed to get contacts: ' + ex.getMessage()
      );
    }
  }

  /**
   * @description 搜索联系人（简化版分页查询）
   */
  @AuraEnabled(cacheable=true)
  public static List<ContactSummary> searchContacts(
    String searchTerm,
    Integer limitCount
  ) {
    if (limitCount == null || limitCount < 1 || limitCount > MAX_PAGE_SIZE) {
      limitCount = DEFAULT_PAGE_SIZE;
    }

    ContactFilter filter = new ContactFilter();
    filter.searchTerm = searchTerm;

    String query = buildContactQuery(filter, 'LastName', 'ASC');
    query += ' LIMIT :limitCount';

    try {
      List<Contact> contacts = Database.query(query);
      SObjectAccessDecision accessDecision = Security.stripInaccessible(
        AccessType.READABLE,
        contacts
      );

      List<ContactSummary> summaries = new List<ContactSummary>();
      for (SObject accessibleRecord : accessDecision.getRecords()) {
        summaries.add(new ContactSummary((Contact) accessibleRecord));
      }

      return summaries;
    } catch (Exception ex) {
      throw new AuraHandledException('Search failed: ' + ex.getMessage());
    }
  }

  /**
   * @description 批量创建联系人
   */
  @AuraEnabled
  public static BatchResult batchCreateContacts(
    List<Map<String, String>> contactDataList
  ) {
    if (contactDataList == null || contactDataList.isEmpty()) {
      throw new ValidationException('Contact data list cannot be empty');
    }

    BatchResult result = new BatchResult(contactDataList.size());
    List<Contact> contactsToInsert = new List<Contact>();

    // 准备数据
    for (Integer i = 0; i < contactDataList.size(); i++) {
      Map<String, String> contactData = contactDataList[i];

      try {
        validateContactData(contactData);

        Contact newContact = new Contact(
          FirstName = normalizeValue(contactData.get('firstName')),
          LastName = normalizeValue(contactData.get('lastName')),
          Email = normalizeValue(contactData.get('email')),
          Title = normalizeValue(contactData.get('title'))
        );

        // 可选字段
        if (contactData.containsKey('accountId')) {
          newContact.AccountId = contactData.get('accountId');
        }

        contactsToInsert.add(newContact);
      } catch (Exception ex) {
        result.incrementFailure('Record ' + (i + 1) + ': ' + ex.getMessage());
      }
    }

    // 批量插入
    if (!contactsToInsert.isEmpty()) {
      try {
        // 应用安全过滤（可写检查）
        SObjectAccessDecision accessDecision = Security.stripInaccessible(
          AccessType.CREATABLE,
          contactsToInsert
        );

        Database.SaveResult[] saveResults = Database.insert(
          accessDecision.getRecords(),
          false // 允许部分失败
        );

        // 处理插入结果
        for (Database.SaveResult saveResult : saveResults) {
          if (saveResult.isSuccess()) {
            result.incrementSuccess();
          } else {
            String errorMsg = '';
            for (Database.Error error : saveResult.getErrors()) {
              errorMsg += error.getMessage() + '; ';
            }
            result.incrementFailure(errorMsg);
          }
        }
      } catch (Exception ex) {
        result.incrementFailure('Batch insert failed: ' + ex.getMessage());
      }
    }

    return result;
  }

  /**
   * @description 更新联系人状态（示例方法）
   */
  @AuraEnabled
  public static Boolean updateContactStatus(Id contactId, String newStatus) {
    if (String.isBlank(contactId)) {
      throw new ValidationException('Contact ID is required');
    }

    if (String.isBlank(newStatus)) {
      throw new ValidationException('New status is required');
    }

    try {
      // 在实际业务中，这里可能会有更复杂的逻辑
      // 比如更新自定义状态字段、记录状态变更历史等
      Contact contactToUpdate = new Contact(Id = contactId);

      // 这里简化处理 - 实际中可能需要更新具体字段
      // contactToUpdate.Status__c = newStatus;

      // 应用安全过滤
      SObjectAccessDecision accessDecision = Security.stripInaccessible(
        AccessType.UPDATABLE,
        new List<Contact>{ contactToUpdate }
      );

      update accessDecision.getRecords();
      return true;
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Failed to update contact status: ' + ex.getMessage()
      );
    }
  }

  /**
   * @description 验证联系人数据
   */
  private static void validateContactData(Map<String, String> contactData) {
    if (contactData == null) {
      throw new ValidationException('Contact data cannot be null');
    }

    String lastName = contactData.get('lastName');
    if (String.isBlank(lastName)) {
      throw new ValidationException('Last name is required');
    }

    String email = contactData.get('email');
    if (String.isNotBlank(email)) {
      // 简单的邮箱格式验证
      String emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
      Pattern emailPattern = Pattern.compile(emailRegex);
      Matcher emailMatcher = emailPattern.matcher(email);

      if (!emailMatcher.matches()) {
        throw new ValidationException('Invalid email format');
      }
    }
  }

  /**
   * @description 获取联系人统计信息
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Integer> getContactStatistics() {
    Map<String, Integer> stats = new Map<String, Integer>();

    try {
      // 总联系人数量
      Integer totalContacts = [
        SELECT COUNT()
        FROM Contact
        WITH SECURITY_ENFORCED
      ];
      stats.put('totalContacts', totalContacts);

      // 今日更新的联系人数量
      Integer todayUpdated = [
        SELECT COUNT()
        FROM Contact
        WHERE LastModifiedDate = TODAY
        WITH SECURITY_ENFORCED
      ];
      stats.put('todayUpdated', todayUpdated);

      // 最近30天创建的联系人数量
      Integer recentCreated = [
        SELECT COUNT()
        FROM Contact
        WHERE CreatedDate = LAST_N_DAYS:30
        WITH SECURITY_ENFORCED
      ];
      stats.put('recentCreated', recentCreated);

      // 有邮箱的联系人数量
      Integer withEmail = [
        SELECT COUNT()
        FROM Contact
        WHERE Email != NULL
        WITH SECURITY_ENFORCED
      ];
      stats.put('withEmail', withEmail);
    } catch (Exception ex) {
      // 发生错误时返回空统计
      System.debug('Error getting contact statistics: ' + ex.getMessage());
    }

    return stats;
  }

  /**
   * @description 获取可用的联系人状态选项
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getStatusOptions() {
    List<Map<String, String>> options = new List<Map<String, String>>();

    options.add(
      new Map<String, String>{
        'label' => 'Active',
        'value' => 'Active',
        'description' => 'Recently active contacts'
      }
    );

    options.add(
      new Map<String, String>{
        'label' => 'New',
        'value' => 'New',
        'description' => 'Contacts created in last 30 days'
      }
    );

    options.add(
      new Map<String, String>{
        'label' => 'Standard',
        'value' => 'Standard',
        'description' => 'Regular contacts'
      }
    );

    options.add(
      new Map<String, String>{
        'label' => 'Incomplete',
        'value' => 'Incomplete',
        'description' => 'Contacts missing required information'
      }
    );

    return options;
  }
}
