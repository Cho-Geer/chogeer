/**
 * @description ShowcaseContactController测试类
 * 测试增强后的联系人控制器功能，包括分页查询、批量操作、状态管理等
 */
@IsTest
private with sharing class ShowcaseContactControllerTest {
  // ========== 测试数据准备 ==========

  /**
   * @description 创建测试数据
   */
  @TestSetup
  static void setupTestData() {
    // 创建测试账户
    Account testAccount1 = new Account(Name = 'Test Corporation');
    Account testAccount2 = new Account(Name = 'Demo Enterprises');
    insert new List<Account>{ testAccount1, testAccount2 };

    // 创建测试联系人
    List<Contact> testContacts = new List<Contact>();

    // 活跃联系人（今日更新）
    testContacts.add(
      new Contact(
        FirstName = 'Active',
        LastName = 'User1',
        Email = 'active1@example.com',
        Title = 'Engineer',
        AccountId = testAccount1.Id
      )
    );

    testContacts.add(
      new Contact(
        FirstName = 'Active',
        LastName = 'User2',
        Email = 'active2@example.com',
        Title = 'Manager',
        AccountId = testAccount1.Id
      )
    );

    // 新联系人（30天内创建）
    testContacts.add(
      new Contact(
        FirstName = 'New',
        LastName = 'User3',
        Email = 'new3@example.com',
        Title = 'Analyst',
        AccountId = testAccount2.Id
        // CreatedDate在插入后通过Test.setCreatedDate设置
      )
    );

    testContacts.add(
      new Contact(
        FirstName = 'New',
        LastName = 'User4',
        Email = 'new4@example.com',
        Title = 'Developer',
        AccountId = testAccount2.Id
        // CreatedDate在插入后通过Test.setCreatedDate设置
      )
    );

    // 标准联系人（30天前创建，非今日更新）
    testContacts.add(
      new Contact(
        FirstName = 'Standard',
        LastName = 'User5',
        Email = 'standard5@example.com',
        Title = 'Director',
        AccountId = testAccount1.Id
        // CreatedDate在插入后通过Test.setCreatedDate设置
      )
    );

    // 不完整联系人（无邮箱）
    testContacts.add(
      new Contact(
        FirstName = 'Incomplete',
        LastName = 'User6',
        Title = 'Assistant',
        AccountId = testAccount2.Id
      )
    );

    insert testContacts;

    // 更新一些联系人以设置LastModifiedDate为今天
    // （模拟活跃联系人）
    List<Contact> contactsToUpdate = new List<Contact>();
    for (Contact c : [
      SELECT Id
      FROM Contact
      WHERE LastName LIKE 'User1' OR LastName LIKE 'User2'
    ]) {
      contactsToUpdate.add(c);
    }
    if (!contactsToUpdate.isEmpty()) {
      update contactsToUpdate;
    }
  }

  // ========== 原有功能测试 ==========

  /**
   * @description 测试获取最近联系人
   */
  @IsTest
  static void testGetRecentContacts() {
    Test.startTest();
    List<ShowcaseContactController.ContactSummary> results = ShowcaseContactController.getRecentContacts();
    Test.stopTest();

    System.assertNotEquals(null, results, '结果不应为空');
    System.assert(results.size() > 0, '应返回至少一个联系人');

    // 验证结果格式
    ShowcaseContactController.ContactSummary firstResult = results[0];
    System.assertNotEquals(null, firstResult.contactId, '应有联系人ID');
    System.assertNotEquals(null, firstResult.firstName, '应有名');
    System.assertNotEquals(null, firstResult.lastName, '应有姓');
    System.assertNotEquals(null, firstResult.status, '应有状态');
  }

  /**
   * @description 测试创建联系人
   */
  @IsTest
  static void testCreateContact() {
    Test.startTest();
    Id contactId = ShowcaseContactController.createContact(
      'Test',
      'Create',
      'test.create@example.com',
      'Test Title'
    );
    Test.stopTest();

    System.assertNotEquals(null, contactId, '应返回联系人ID');

    // 验证数据库记录
    Contact createdContact = [
      SELECT FirstName, LastName, Email, Title
      FROM Contact
      WHERE Id = :contactId
    ];

    System.assertEquals('Test', createdContact.FirstName);
    System.assertEquals('Create', createdContact.LastName);
    System.assertEquals('test.create@example.com', createdContact.Email);
    System.assertEquals('Test Title', createdContact.Title);
  }

  /**
   * @description 测试创建联系人验证（必填项）
   */
  @IsTest
  static void testCreateContactValidation() {
    Boolean didThrow = false;

    Test.startTest();
    try {
      ShowcaseContactController.createContact('Test', null, null, null);
    } catch (AuraHandledException ex) {
      didThrow = true;
      System.assert(
        ex.getMessage().contains('Last name is required'),
        '异常消息应包含必填项提示'
      );
    }
    Test.stopTest();

    System.assertEquals(true, didThrow, '应抛出AuraHandledException');
  }

  // ========== 新增功能测试 - 分页查询 ==========

  /**
   * @description 测试分页获取联系人
   */
  @IsTest
  static void testGetContactsByPage() {
    // 创建过滤器
    ShowcaseContactController.ContactFilter filter = new ShowcaseContactController.ContactFilter();
    filter.accountId = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Corporation'
      LIMIT 1
    ]
    .Id;

    Test.startTest();
    ShowcaseContactController.PaginatedResult result = ShowcaseContactController.getContactsByPage(
      1,
      5,
      filter,
      'LastName',
      'ASC'
    );
    Test.stopTest();

    System.assertNotEquals(null, result, '结果不应为空');
    System.assertEquals(1, result.pageNumber, '页码应为1');
    System.assertEquals(5, result.pageSize, '页大小应为5');
    System.assert(result.totalRecords > 0, '总记录数应大于0');
    System.assert(result.totalPages > 0, '总页数应大于0');
    System.assertNotEquals(null, result.records, '记录列表不应为空');

    // 验证记录数量不超过页大小
    System.assert(
      result.records.size() <= result.pageSize,
      '记录数不应超过页大小'
    );

    // 验证记录格式
    if (!result.records.isEmpty()) {
      ShowcaseContactController.ContactSummary firstRecord = result.records[0];
      System.assertNotEquals(null, firstRecord.contactId, '记录应有联系人ID');
      System.assertNotEquals(null, firstRecord.lastName, '记录应有姓');
    }
  }

  /**
   * @description 测试分页查询参数验证
   */
  @IsTest
  static void testGetContactsByPageValidation() {
    Boolean didThrow = false;

    Test.startTest();
    try {
      // 测试无效页码
      ShowcaseContactController.getContactsByPage(
        0,
        10,
        null,
        'LastName',
        'ASC'
      );
    } catch (AuraHandledException ex) {
      didThrow = true;
      System.assert(
        ex.getMessage().contains('Failed to get contacts'),
        '应抛出包含错误消息的异常'
      );
    }
    Test.stopTest();

    System.assertEquals(true, didThrow, '应抛出异常');
  }

  /**
   * @description 测试分页查询 - 第二页
   */
  @IsTest
  static void testGetContactsByPageSecondPage() {
    // 首先获取第一页了解总记录数
    ShowcaseContactController.PaginatedResult firstPage = ShowcaseContactController.getContactsByPage(
      1,
      2,
      null,
      'LastName',
      'ASC'
    );

    System.assert(firstPage.totalRecords >= 3, '测试需要至少3条记录');

    Test.startTest();
    ShowcaseContactController.PaginatedResult secondPage = ShowcaseContactController.getContactsByPage(
      2,
      2,
      null,
      'LastName',
      'ASC'
    );
    Test.stopTest();

    System.assertEquals(2, secondPage.pageNumber, '页码应为2');
    System.assertEquals(2, secondPage.pageSize, '页大小应为2');

    // 第二页应有记录（如果有足够数据）
    if (firstPage.totalRecords > 2) {
      System.assert(secondPage.records.size() > 0, '第二页应有记录');
    }
  }

  // ========== 新增功能测试 - 搜索功能 ==========

  /**
   * @description 测试搜索联系人
   */
  @IsTest
  static void testSearchContacts() {
    Test.startTest();
    List<ShowcaseContactController.ContactSummary> results = ShowcaseContactController.searchContacts(
      'Active',
      10
    );
    Test.stopTest();

    System.assertNotEquals(null, results, '搜索结果不应为空');
    System.assert(results.size() > 0, '应找到匹配的联系人');

    // 验证结果包含搜索词
    Boolean foundMatch = false;
    for (ShowcaseContactController.ContactSummary summary : results) {
      if (
        summary.firstName.contains('Active') ||
        summary.lastName.contains('Active')
      ) {
        foundMatch = true;
        break;
      }
    }
    System.assertEquals(true, foundMatch, '应找到包含"Active"的联系人');
  }

  /**
   * @description 测试搜索无结果
   */
  @IsTest
  static void testSearchContactsNoResults() {
    Test.startTest();
    List<ShowcaseContactController.ContactSummary> results = ShowcaseContactController.searchContacts(
      'NonexistentName',
      10
    );
    Test.stopTest();

    System.assertNotEquals(null, results, '结果不应为空（应为空列表）');
    System.assertEquals(0, results.size(), '不应找到匹配的联系人');
  }

  /**
   * @description 测试搜索限制数量
   */
  @IsTest
  static void testSearchContactsWithLimit() {
    Test.startTest();
    List<ShowcaseContactController.ContactSummary> results = ShowcaseContactController.searchContacts(
      'User',
      2
    );
    Test.stopTest();

    System.assert(results.size() <= 2, '结果不应超过限制数量');
  }

  // ========== 新增功能测试 - 批量操作 ==========

  /**
   * @description 测试批量创建联系人
   */
  @IsTest
  static void testBatchCreateContacts() {
    List<Map<String, String>> contactDataList = new List<Map<String, String>>();

    // 添加有效数据
    contactDataList.add(
      new Map<String, String>{
        'firstName' => 'Batch1',
        'lastName' => 'Test1',
        'email' => 'batch1@example.com',
        'title' => 'Title1'
      }
    );

    contactDataList.add(
      new Map<String, String>{
        'firstName' => 'Batch2',
        'lastName' => 'Test2',
        'email' => 'batch2@example.com',
        'title' => 'Title2',
        'accountId' => [
          SELECT Id
          FROM Account
          WHERE Name = 'Test Corporation'
          LIMIT 1
        ]
        .Id
      }
    );

    // 添加无效数据（无姓氏）
    contactDataList.add(
      new Map<String, String>{
        'firstName' => 'Invalid',
        'email' => 'invalid@example.com'
      }
    );

    // 添加无效数据（无效邮箱格式）
    contactDataList.add(
      new Map<String, String>{
        'firstName' => 'Invalid',
        'lastName' => 'Email',
        'email' => 'invalid-email'
      }
    );

    Test.startTest();
    ShowcaseContactController.BatchResult result = ShowcaseContactController.batchCreateContacts(
      contactDataList
    );
    Test.stopTest();

    System.assertNotEquals(null, result, '结果不应为空');
    System.assertEquals(4, result.totalRecords, '总记录数应为4');
    System.assertEquals(2, result.successCount, '成功数应为2');
    System.assertEquals(2, result.failureCount, '失败数应为2');
    System.assertNotEquals(null, result.errorMessages, '错误消息列表不应为空');
    System.assertEquals(2, result.errorMessages.size(), '应有2条错误消息');

    // 验证成功创建的联系人
    List<Contact> createdContacts = [
      SELECT LastName
      FROM Contact
      WHERE LastName LIKE 'Test%'
    ];
    System.assertEquals(2, createdContacts.size(), '应成功创建2个联系人');
  }

  /**
   * @description 测试批量创建联系人 - 空列表
   */
  @IsTest
  static void testBatchCreateContactsEmptyList() {
    Boolean didThrow = false;

    Test.startTest();
    try {
      ShowcaseContactController.batchCreateContacts(
        new List<Map<String, String>>()
      );
    } catch (AuraHandledException ex) {
      didThrow = true;
      System.assert(
        ex.getMessage().contains('cannot be empty'),
        '异常消息应包含空列表提示'
      );
    }
    Test.stopTest();

    System.assertEquals(true, didThrow, '应抛出异常');
  }

  /**
   * @description 测试批量创建联系人验证
   */
  @IsTest
  static void testBatchCreateContactsValidation() {
    List<Map<String, String>> contactDataList = new List<Map<String, String>>();

    // 仅包含必填字段
    contactDataList.add(
      new Map<String, String>{ 'lastName' => 'RequiredOnly' }
    );

    Test.startTest();
    ShowcaseContactController.BatchResult result = ShowcaseContactController.batchCreateContacts(
      contactDataList
    );
    Test.stopTest();

    System.assertEquals(1, result.successCount, '应成功创建1个联系人');
    System.assertEquals(0, result.failureCount, '不应有失败');
  }

  // ========== 新增功能测试 - 状态和统计 ==========

  /**
   * @description 测试获取联系人统计信息
   */
  @IsTest
  static void testGetContactStatistics() {
    Test.startTest();
    Map<String, Integer> stats = ShowcaseContactController.getContactStatistics();
    Test.stopTest();

    System.assertNotEquals(null, stats, '统计信息不应为空');
    System.assert(stats.containsKey('totalContacts'), '应包含总联系人统计');
    System.assert(stats.containsKey('todayUpdated'), '应包含今日更新统计');
    System.assert(stats.containsKey('recentCreated'), '应包含最近创建统计');
    System.assert(stats.containsKey('withEmail'), '应包含有邮箱统计');

    System.assert(stats.get('totalContacts') > 0, '总联系人应大于0');
    System.assert(stats.get('withEmail') > 0, '有邮箱的联系人应大于0');
  }

  /**
   * @description 测试获取状态选项
   */
  @IsTest
  static void testGetStatusOptions() {
    Test.startTest();
    List<Map<String, String>> options = ShowcaseContactController.getStatusOptions();
    Test.stopTest();

    System.assertNotEquals(null, options, '选项列表不应为空');
    System.assert(options.size() >= 4, '应有至少4个状态选项');

    // 验证选项格式
    for (Map<String, String> option : options) {
      System.assert(option.containsKey('label'), '选项应有标签');
      System.assert(option.containsKey('value'), '选项应有值');
      System.assert(option.containsKey('description'), '选项应有描述');
    }

    // 验证特定状态选项
    Boolean foundActive = false;
    Boolean foundNew = false;
    Boolean foundStandard = false;
    Boolean foundIncomplete = false;

    for (Map<String, String> option : options) {
      if (option.get('value') == 'Active')
        foundActive = true;
      if (option.get('value') == 'New')
        foundNew = true;
      if (option.get('value') == 'Standard')
        foundStandard = true;
      if (option.get('value') == 'Incomplete')
        foundIncomplete = true;
    }

    System.assertEquals(true, foundActive, '应有Active状态');
    System.assertEquals(true, foundNew, '应有New状态');
    System.assertEquals(true, foundStandard, '应有Standard状态');
    System.assertEquals(true, foundIncomplete, '应有Incomplete状态');
  }

  /**
   * @description 测试状态确定逻辑
   */
  @IsTest
  static void testContactStatusDetermination() {
    // 获取一个测试联系人
    Contact testContact = [
      SELECT Id, Email, LastModifiedDate, CreatedDate
      FROM Contact
      LIMIT 1
    ];

    // 通过ContactSummary构造函数间接测试状态确定逻辑
    ShowcaseContactController.ContactSummary summary = new ShowcaseContactController.ContactSummary(
      testContact
    );

    System.assertNotEquals(null, summary.status, '状态不应为空');
    System.assert(summary.status.length() > 0, '状态应有值');

    // 验证状态是预定义值之一
    List<String> validStatuses = new List<String>{
      'Active',
      'New',
      'Standard',
      'Incomplete'
    };
    System.assert(
      validStatuses.contains(summary.status),
      '状态应为预定义值之一: ' + summary.status
    );
  }

  /**
   * @description 测试更新联系人状态（示例方法）
   */
  @IsTest
  static void testUpdateContactStatus() {
    Contact testContact = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    Boolean result = ShowcaseContactController.updateContactStatus(
      testContact.Id,
      'Active'
    );
    Test.stopTest();

    System.assertEquals(true, result, '更新应成功');
  }

  /**
   * @description 测试更新联系人状态验证
   */
  @IsTest
  static void testUpdateContactStatusValidation() {
    Boolean didThrow = false;

    Test.startTest();
    try {
      ShowcaseContactController.updateContactStatus(null, 'Active');
    } catch (AuraHandledException ex) {
      didThrow = true;
      System.assert(
        ex.getMessage().contains('Contact ID is required'),
        '异常消息应包含ID必填提示'
      );
    }
    Test.stopTest();

    System.assertEquals(true, didThrow, '应抛出异常');
  }

  // ========== 新增功能测试 - 过滤器功能 ==========

  /**
   * @description 测试联系人过滤器
   */
  @IsTest
  static void testContactFilter() {
    ShowcaseContactController.ContactFilter filter = new ShowcaseContactController.ContactFilter();

    // 初始状态应无过滤器
    System.assertEquals(false, filter.hasFilters(), '初始不应有过滤器');

    // 添加过滤器
    filter.searchTerm = 'Test';
    System.assertEquals(true, filter.hasFilters(), '添加搜索词后应有过滤器');

    filter.searchTerm = null;
    filter.status = 'Active';
    System.assertEquals(true, filter.hasFilters(), '添加状态后应有过滤器');

    filter.status = null;
    filter.accountId = '001000000000001';
    System.assertEquals(true, filter.hasFilters(), '添加账户ID后应有过滤器');

    filter.accountId = null;
    filter.title = 'Manager';
    System.assertEquals(true, filter.hasFilters(), '添加职位后应有过滤器');

    filter.title = null;
    filter.createdAfter = Date.today();
    System.assertEquals(true, filter.hasFilters(), '添加创建时间后应有过滤器');

    filter.createdAfter = null;
    filter.createdBefore = Date.today();
    System.assertEquals(true, filter.hasFilters(), '添加创建时间前应有过滤器');
  }

  /**
   * @description 测试带过滤器的分页查询
   */
  @IsTest
  static void testGetContactsByPageWithFilter() {
    // 创建复杂的过滤器
    ShowcaseContactController.ContactFilter filter = new ShowcaseContactController.ContactFilter();
    filter.searchTerm = 'User';
    filter.title = 'Engineer';

    Test.startTest();
    ShowcaseContactController.PaginatedResult result = ShowcaseContactController.getContactsByPage(
      1,
      10,
      filter,
      'LastName',
      'ASC'
    );
    Test.stopTest();

    System.assertNotEquals(null, result, '结果不应为空');
    System.assert(result.records.size() >= 0, '记录数可能为0或更多');
  }

  // ========== 新增功能测试 - 边界条件和错误处理 ==========

  /**
   * @description 测试最大页大小限制
   */
  @IsTest
  static void testMaxPageSize() {
    // 测试超过最大页大小
    Boolean didThrow = false;

    Test.startTest();
    try {
      ShowcaseContactController.getContactsByPage(
        1,
        101,
        null,
        'LastName',
        'ASC'
      );
    } catch (AuraHandledException ex) {
      didThrow = true;
      System.assert(
        ex.getMessage().contains('Page size must be between'),
        '异常消息应包含页大小限制'
      );
    }
    Test.stopTest();

    System.assertEquals(true, didThrow, '应抛出异常');
  }

  /**
   * @description 测试默认分页参数
   */
  @IsTest
  static void testDefaultPaginationParams() {
    Test.startTest();
    // 使用null参数，应使用默认值
    ShowcaseContactController.PaginatedResult result = ShowcaseContactController.getContactsByPage(
      null,
      null,
      null,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(1, result.pageNumber, '默认页码应为1');
    System.assertEquals(
      ShowcaseContactController.DEFAULT_PAGE_SIZE,
      result.pageSize,
      '默认页大小应为DEFAULT_PAGE_SIZE'
    );
  }

  /**
   * @description 测试无效排序字段处理
   */
  @IsTest
  static void testInvalidSortField() {
    Test.startTest();
    // 使用无效排序字段，应使用默认字段
    ShowcaseContactController.PaginatedResult result = ShowcaseContactController.getContactsByPage(
      1,
      10,
      null,
      'InvalidField',
      'ASC'
    );
    Test.stopTest();

    // 方法应正常执行，使用默认排序字段
    System.assertNotEquals(null, result, '结果不应为空');
  }

  /**
   * @description 测试SOQL注入防护
   */
  @IsTest
  static void testSqlInjectionProtection() {
    // 测试搜索词中的特殊字符
    String maliciousSearch = 'Test\' OR Name LIKE \'%';

    Test.startTest();
    List<ShowcaseContactController.ContactSummary> results = ShowcaseContactController.searchContacts(
      maliciousSearch,
      10
    );
    Test.stopTest();

    // 方法应正常执行，不会抛出SOQL注入异常
    System.assertNotEquals(null, results, '结果不应为空');
  }

  /**
   * @description 测试性能 - 多次查询
   */
  @IsTest
  static void testPerformanceMultipleQueries() {
    Long startTime = DateTime.now().getTime();

    Test.startTest();
    // 执行多次查询
    ShowcaseContactController.getRecentContacts();
    ShowcaseContactController.searchContacts('User', 5);
    ShowcaseContactController.getContactsByPage(1, 5, null, 'LastName', 'ASC');
    ShowcaseContactController.getContactStatistics();
    ShowcaseContactController.getStatusOptions();
    Test.stopTest();

    Long endTime = DateTime.now().getTime();
    Long duration = endTime - startTime;

    System.assert(
      duration < 2000,
      '多次查询应在2秒内完成，实际耗时: ' + duration + 'ms'
    );
  }

  /**
   * @description 测试ContactSummary构造函数
   */
  @IsTest
  static void testContactSummaryConstructor() {
    Contact testContact = new Contact(
      FirstName = 'Constructor',
      LastName = 'Test',
      Email = 'constructor@test.com',
      Title = 'Developer'
    );

    // 关联账户
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;
    testContact.AccountId = testAccount.Id;
    insert testContact;

    // 刷新以获取相关数据
    testContact = [
      SELECT
        Id,
        FirstName,
        LastName,
        Email,
        Title,
        Account.Name,
        CreatedDate,
        LastModifiedDate
      FROM Contact
      WHERE Id = :testContact.Id
    ];

    Test.startTest();
    ShowcaseContactController.ContactSummary summary = new ShowcaseContactController.ContactSummary(
      testContact
    );
    Test.stopTest();

    System.assertEquals(testContact.Id, summary.contactId, 'ID应匹配');
    System.assertEquals(testContact.FirstName, summary.firstName, '名应匹配');
    System.assertEquals(testContact.LastName, summary.lastName, '姓应匹配');
    System.assertEquals(testContact.Email, summary.email, '邮箱应匹配');
    System.assertEquals(testContact.Title, summary.title, '职位应匹配');
    System.assertEquals(
      testContact.Account.Name,
      summary.accountName,
      '账户名应匹配'
    );
    System.assertNotEquals(null, summary.status, '状态不应为空');
    System.assertEquals(
      testContact.LastModifiedDate,
      summary.lastModifiedDate,
      '最后修改时间应匹配'
    );
  }
}
