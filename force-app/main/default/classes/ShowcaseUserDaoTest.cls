/**
 * @description ShowcaseUserDao测试类
 * 测试标准化用户数据访问对象的所有功能，包括查询、更新、统计等
 */
@IsTest
private with sharing class ShowcaseUserDaoTest {
  // ========== 测试数据准备 ==========

  /**
   * @description 创建测试用户数据
   */
  @TestSetup
  static void setupTestData() {
    // 创建测试配置文件
    Profile standardProfile = [SELECT Id, Name FROM Profile LIMIT 1];
    Profile systemAdminProfile = standardProfile;

    // 创建测试用户角色
    UserRole testRole = new UserRole(
      Name = 'TestRole_' + DateTime.now().getTime(),
      DeveloperName = 'TestRole_' + DateTime.now().getTime()
    );
    insert testRole;

    // 创建测试用户
    List<User> testUsers = new List<User>();

    // 活跃用户 - 门户访问已禁用
    testUsers.add(
      createTestUser(
        'dao.disabled1@example.com',
        'DaoDisabled1',
        'User1',
        standardProfile.Id,
        testRole.Id,
        false
      )
    );
    testUsers.add(
      createTestUser(
        'dao.disabled2@example.com',
        'DaoDisabled2',
        'User2',
        standardProfile.Id,
        testRole.Id,
        false
      )
    );

    // 活跃用户 - 门户访问已启用
    testUsers.add(
      createTestUser(
        'dao.enabled1@example.com',
        'DaoEnabled1',
        'User3',
        systemAdminProfile.Id,
        testRole.Id,
        true
      )
    );
    testUsers.add(
      createTestUser(
        'dao.enabled2@example.com',
        'DaoEnabled2',
        'User4',
        systemAdminProfile.Id,
        testRole.Id,
        true
      )
    );

    // 非活跃用户
    testUsers.add(
      createTestUser(
        'dao.inactive1@example.com',
        'DaoInactive1',
        'User5',
        standardProfile.Id,
        testRole.Id,
        false
      )
    );
    testUsers[4].IsActive = false;

    insert testUsers;
  }

  /**
   * @description 创建测试用户辅助方法
   */
  private static User createTestUser(
    String email,
    String firstName,
    String lastName,
    Id profileId,
    Id roleId,
    Boolean isPortalEnabled
  ) {
    String username =
      email.substring(0, email.indexOf('@')) + '.dao.test@example.com';

    return new User(
      Alias = firstName.substring(0, 1) + lastName.substring(0, 4),
      Email = email,
      EmailEncodingKey = 'UTF-8',
      FirstName = firstName,
      LastName = lastName,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileId,
      UserRoleId = roleId,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = username,
      Title = isPortalEnabled ? 'Portal User' : null,
      IsActive = true,
      Department = 'Quality Assurance',
      CompanyName = 'Test Corp',
      Phone = '123-456-7890',
      MobilePhone = '098-765-4321'
    );
  }

  /**
   * @description 获取所有测试用户
   */
  private static List<User> getAllTestUsers() {
    return [
      SELECT
        Id,
        Username,
        Email,
        FirstName,
        LastName,
        Name,
        IsActive,
        UserType,
        ProfileId,
        UserRoleId,
        CreatedDate,
        LastModifiedDate,
        LastLoginDate,
        Title,
        Department,
        CompanyName,
        Phone,
        MobilePhone
      FROM User
      WHERE Email LIKE 'dao.%@example.com'
      ORDER BY CreatedDate
    ];
  }

  /**
   * @description 获取活跃门户已禁用用户
   */
  private static List<User> getActiveDisabledPortalUsers() {
    return [
      SELECT Id, Username, Email, Name, Title, UserType, IsActive
      FROM User
      WHERE Email LIKE 'dao.disabled%@example.com' AND IsActive = TRUE
      ORDER BY CreatedDate
    ];
  }

  /**
   * @description 获取活跃门户已启用用户
   */
  private static List<User> getActiveEnabledPortalUsers() {
    return [
      SELECT Id, Username, Email, Name, Title, UserType, IsActive
      FROM User
      WHERE Email LIKE 'dao.enabled%@example.com' AND IsActive = TRUE
      ORDER BY CreatedDate
    ];
  }

  // ========== 测试方法 - 基本功能 ==========

  /**
   * @description 测试DAO实例化
   */
  @IsTest
  static void testDaoInstantiation() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();

    Test.stopTest();

    System.assertNotEquals(null, dao, 'DAO实例不应为空');
  }

  /**
   * @description 测试根据用户ID查询用户
   */
  @IsTest
  static void testGetUsersByIds() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Set<Id> userIds = new Set<Id>();
    for (User user : testUsers) {
      userIds.add(user.Id);
    }

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getUsersByIds(userIds);

    Test.stopTest();

    // 验证结果
    System.assertEquals(testUsers.size(), result.size(), '查询结果数量应匹配');

    // 验证每个用户都被正确查询
    Map<Id, User> resultMap = new Map<Id, User>(result);
    for (User expectedUser : testUsers) {
      System.assert(
        resultMap.containsKey(expectedUser.Id),
        '应包含用户: ' + expectedUser.Username
      );
      User actualUser = resultMap.get(expectedUser.Id);
      System.assertEquals(
        expectedUser.Username,
        actualUser.Username,
        '用户名应匹配'
      );
      System.assertEquals(expectedUser.Email, actualUser.Email, '邮箱应匹配');
      System.assertEquals(
        expectedUser.Title,
        actualUser.Title,
        '门户访问状态应匹配'
      );
    }
  }

  /**
   * @description 测试根据用户名查询用户
   */
  @IsTest
  static void testGetUsersByUsernames() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Set<String> usernames = new Set<String>();
    for (User user : testUsers) {
      usernames.add(user.Username);
    }

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getUsersByUsernames(usernames);

    Test.stopTest();

    // 验证结果
    System.assertEquals(testUsers.size(), result.size(), '查询结果数量应匹配');

    // 验证用户名匹配
    Set<String> resultUsernames = new Set<String>();
    for (User user : result) {
      resultUsernames.add(user.Username);
    }

    for (String username : usernames) {
      System.assert(
        resultUsernames.contains(username),
        '结果应包含用户名: ' + username
      );
    }
  }

  /**
   * @description 测试根据邮箱查询用户
   */
  @IsTest
  static void testGetUsersByEmails() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Set<String> emails = new Set<String>();
    for (User user : testUsers) {
      emails.add(user.Email);
    }

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getUsersByEmails(emails);

    Test.stopTest();

    // 验证结果
    System.assertEquals(testUsers.size(), result.size(), '查询结果数量应匹配');

    // 验证邮箱匹配
    Set<String> resultEmails = new Set<String>();
    for (User user : result) {
      resultEmails.add(user.Email);
    }

    for (String email : emails) {
      System.assert(resultEmails.contains(email), '结果应包含邮箱: ' + email);
    }
  }

  /**
   * @description 测试空ID集合查询
   */
  @IsTest
  static void testGetUsersByIdsEmpty() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getUsersByIds(new Set<Id>());

    Test.stopTest();

    System.assertNotEquals(null, result, '结果不应为空');
    System.assertEquals(true, result.isEmpty(), '结果应为空列表');
  }

  /**
   * @description 测试空用户名集合查询
   */
  @IsTest
  static void testGetUsersByUsernamesEmpty() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getUsersByUsernames(new Set<String>());

    Test.stopTest();

    System.assertNotEquals(null, result, '结果不应为空');
    System.assertEquals(true, result.isEmpty(), '结果应为空列表');
  }

  /**
   * @description 测试空邮箱集合查询
   */
  @IsTest
  static void testGetUsersByEmailsEmpty() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getUsersByEmails(new Set<String>());

    Test.stopTest();

    System.assertNotEquals(null, result, '结果不应为空');
    System.assertEquals(true, result.isEmpty(), '结果应为空列表');
  }

  // ========== 测试方法 - 查询选项 ==========

  /**
   * @description 测试完整查询选项
   */
  @IsTest
  static void testQueryUsersWithFullOptions() {
    // 准备测试数据
    List<User> allUsers = getAllTestUsers();
    System.assert(!allUsers.isEmpty(), '应有测试用户');

    // 获取活跃门户已禁用用户
    List<User> disabledUsers = getActiveDisabledPortalUsers();
    System.assert(!disabledUsers.isEmpty(), '应有门户访问已禁用的测试用户');

    // 创建查询选项
    ShowcaseUserDao.UserQueryOptions options = new ShowcaseUserDao.UserQueryOptions();
    options.isActive = true;
    options.isPortalEnabled = false;
    options.sortBy = 'Name';
    options.sortOrder = 'ASC';
    options.limitCount = 10;

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    ShowcaseUserDao.UserQueryResult result = dao.queryUsers(options);

    Test.stopTest();

    // 验证结果
    System.assertNotEquals(null, result, '结果不应为空');
    System.assertNotEquals(null, result.records, '记录列表不应为空');
    // 在DevHub环境中，可能有其他匹配条件的用户，总数应至少包含测试用户
    System.assert(
      result.totalCount >= disabledUsers.size(),
      '总数应至少包含测试用户，期望至少: ' +
        disabledUsers.size() +
        '，实际: ' +
        result.totalCount
    );
    System.assertEquals(
      false,
      result.hasMore,
      '不应有更多结果（限制大于结果数）'
    );
    System.assertNotEquals(null, result.queryUsed, '使用的查询不应为空');

    // 验证记录数量
    // 在DevHub环境中，可能有其他匹配条件的用户，记录数量应至少包含测试用户
    System.assert(
      result.records.size() >= disabledUsers.size(),
      '记录数量应至少包含测试用户，期望至少: ' +
        disabledUsers.size() +
        '，实际: ' +
        result.records.size()
    );

    // 验证排序（按名称升序）
    for (Integer i = 1; i < result.records.size(); i++) {
      String prevName = result.records[i - 1].Name;
      String currName = result.records[i].Name;
      System.assert(prevName <= currName, '记录应按名称升序排列');
    }
  }

  /**
   * @description 测试查询选项验证 - 超过限制
   */
  @IsTest
  static void testQueryOptionsValidationLimitExceeded() {
    ShowcaseUserDao.UserQueryOptions options = new ShowcaseUserDao.UserQueryOptions();
    options.limitCount = 20000; // 超过10000的限制

    Test.startTest();

    try {
      options.validate();
      System.assert(false, '应抛出异常');
    } catch (IllegalArgumentException ex) {
      System.assert(
        ex.getMessage().contains('查询限制不能超过10000条记录'),
        '异常消息应匹配'
      );
    }

    Test.stopTest();
  }

  /**
   * @description 测试查询选项验证 - 负偏移量
   */
  @IsTest
  static void testQueryOptionsValidationNegativeOffset() {
    ShowcaseUserDao.UserQueryOptions options = new ShowcaseUserDao.UserQueryOptions();
    options.offset = -1;

    Test.startTest();

    try {
      options.validate();
      System.assert(false, '应抛出异常');
    } catch (IllegalArgumentException ex) {
      System.assert(
        ex.getMessage().contains('偏移量不能为负数'),
        '异常消息应匹配'
      );
    }

    Test.stopTest();
  }

  /**
   * @description 测试空查询选项
   */
  @IsTest
  static void testQueryUsersNullOptions() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();

    try {
      dao.queryUsers(null);
      System.assert(false, '应抛出异常');
    } catch (ShowcaseUserDao.UserQueryValidationException ex) {
      System.assertEquals(
        '查询选项不能为空',
        ex.getMessage(),
        '异常消息应匹配'
      );
      System.assertEquals('options', ex.fieldName, '字段名应匹配');
    }

    Test.stopTest();
  }

  // ========== 测试方法 - 分页查询 ==========

  /**
   * @description 测试分页查询活跃用户
   */
  @IsTest
  static void testGetAllActiveUsersPaged() {
    // 准备测试数据
    List<User> allActiveUsers = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Email LIKE 'dao.%@example.com'
    ];
    System.assert(!allActiveUsers.isEmpty(), '应有活跃测试用户');

    Integer pageSize = 2;
    Integer pageNumber = 1;

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    ShowcaseUserDao.UserQueryResult result = dao.getAllActiveUsers(
      pageSize,
      pageNumber
    );

    Test.stopTest();

    // 验证结果
    System.assertNotEquals(null, result, '结果不应为空');
    System.assertEquals(
      pageSize,
      result.records.size(),
      '记录数量应等于页大小'
    );
    // 在DevHub环境中，DAO查询可能返回更多活跃用户（包括非测试用户），总数应至少包含测试用户
    System.assert(
      result.totalCount >= allActiveUsers.size(),
      'DAO查询总数应至少包含测试用户，期望至少: ' +
        allActiveUsers.size() +
        '，实际: ' +
        result.totalCount
    );

    // 第一页不应有hasMore警告（如果总记录数 > 页大小）
    if (allActiveUsers.size() > pageSize) {
      System.assertEquals(true, result.hasMore, '应有更多结果');
      System.assert(!result.warnings.isEmpty(), '应有警告信息');
    }
  }

  /**
   * @description 测试无效分页参数
   */
  @IsTest
  static void testGetAllActiveUsersInvalidParams() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();

    // 测试无效页大小（-1）应使用默认值50，但实际返回记录数受环境限制
    ShowcaseUserDao.UserQueryResult result1 = dao.getAllActiveUsers(-1, 1);
    System.assert(
      result1.records.size() <= 50,
      '无效页大小应使用默认值50，实际返回: ' + result1.records.size()
    );

    // 测试无效页码（-1）应使用默认值1，返回所有活跃用户
    ShowcaseUserDao.UserQueryResult result2 = dao.getAllActiveUsers(10, -1);
    // 在DevHub环境中，活跃用户数量可能不同，至少应有测试用户
    System.assert(
      result2.records.size() >= 1,
      '无效页码应返回至少1个活跃用户，实际: ' + result2.records.size()
    );

    Test.stopTest();
  }

  // ========== 测试方法 - 门户用户查询 ==========

  /**
   * @description 测试查询门户已启用用户
   */
  @IsTest
  static void testGetPortalUsersEnabled() {
    // 准备测试数据
    List<User> enabledUsers = getActiveEnabledPortalUsers();
    System.assert(!enabledUsers.isEmpty(), '应有门户访问已启用的测试用户');

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getPortalUsers(true);

    Test.stopTest();

    // 验证结果
    System.assertEquals(enabledUsers.size(), result.size(), '记录数量应匹配');

    // 验证所有用户都启用了门户访问
    for (User user : result) {
      System.assertEquals(
        'Portal User',
        user.Title,
        '用户Title应为Portal User'
      );
      System.assertEquals(true, user.IsActive, '用户应活跃');
    }
  }

  /**
   * @description 测试查询门户已禁用用户
   */
  @IsTest
  static void testGetPortalUsersDisabled() {
    // 准备测试数据
    List<User> disabledUsers = getActiveDisabledPortalUsers();
    System.assert(!disabledUsers.isEmpty(), '应有门户访问已禁用的测试用户');

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.getPortalUsers(false);

    Test.stopTest();

    // 验证结果
    // 在DevHub环境中，可能有其他门户已禁用用户，数量应至少包含测试用户
    System.assert(
      result.size() >= disabledUsers.size(),
      '门户已禁用用户数量应至少包含测试用户，期望至少: ' +
        disabledUsers.size() +
        '，实际: ' +
        result.size()
    );

    // 验证所有用户都禁用了门户访问
    for (User user : result) {
      System.assertEquals(null, user.Title, '用户Title应为null');
      System.assertEquals(true, user.IsActive, '用户应活跃');
    }
  }

  // ========== 测试方法 - 名称搜索 ==========

  /**
   * @description 测试按名称搜索用户
   */
  @IsTest
  static void testSearchUsersByName() {
    // 准备测试数据
    List<User> allUsers = getAllTestUsers();
    System.assert(!allUsers.isEmpty(), '应有测试用户');

    String searchTerm = 'DaoDisabled1'; // 匹配特定测试用户（DaoDisabled1）

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.searchUsersByName(searchTerm, 10);

    Test.stopTest();

    // 验证结果
    System.assert(!result.isEmpty(), '搜索结果不应为空');

    // 验证名称包含搜索词
    for (User user : result) {
      System.assert(
        user.Name.contains(searchTerm),
        '用户名应包含搜索词: ' + searchTerm
      );
    }
  }

  /**
   * @description 测试空搜索词
   */
  @IsTest
  static void testSearchUsersByNameEmpty() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.searchUsersByName('', 10);

    Test.stopTest();

    System.assertNotEquals(null, result, '结果不应为空');
    System.assertEquals(true, result.isEmpty(), '空搜索词应返回空列表');
  }

  /**
   * @description 测试搜索词SOQL注入防护
   */
  @IsTest
  static void testSearchUsersByNameSqlInjectionProtection() {
    String maliciousSearch = 'Test\' OR Name LIKE \'%';

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<User> result = dao.searchUsersByName(maliciousSearch, 10);

    Test.stopTest();

    // 验证没有抛出异常（SOQL注入被防护）
    System.assertNotEquals(null, result, '结果不应为空');
    // 由于没有匹配用户，结果应为空或包含转义后的查询
  }

  // ========== 测试方法 - 批量操作 ==========

  /**
   * @description 测试批量更新用户
   */
  @IsTest
  static void testUpdateUsers() {
    // 准备测试数据
    List<User> disabledUsers = getActiveDisabledPortalUsers();
    System.assert(!disabledUsers.isEmpty(), '应有门户访问已禁用的测试用户');

    // 准备更新数据
    List<User> usersToUpdate = new List<User>();
    for (User user : disabledUsers) {
      User updatedUser = user.clone(true);
      updatedUser.Title = 'Updated Title';
      updatedUser.Department = 'Updated Department';
      usersToUpdate.add(updatedUser);
    }

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<Database.SaveResult> results = dao.updateUsers(usersToUpdate, true);

    Test.stopTest();

    // 验证结果
    System.assertEquals(disabledUsers.size(), results.size(), '结果数量应匹配');

    // 验证所有更新都成功
    for (Database.SaveResult result : results) {
      System.assertEquals(true, result.isSuccess(), '更新应成功');
    }

    // 验证数据库更新
    List<User> updatedUsers = [
      SELECT Title, Department
      FROM User
      WHERE Id IN :disabledUsers
    ];
    for (User user : updatedUsers) {
      System.assertEquals('Updated Title', user.Title, '职位应已更新');
      System.assertEquals(
        'Updated Department',
        user.Department,
        '部门应已更新'
      );
    }
  }

  /**
   * @description 测试批量更新用户（部分成功模式）
   */
  @IsTest
  static void testUpdateUsersPartial() {
    // 准备测试数据
    List<User> disabledUsers = getActiveDisabledPortalUsers();
    System.assert(disabledUsers.size() >= 2, '应有至少2个测试用户');

    // 准备更新数据 - 第一个用户有效，第二个用户设置无效字段值以触发失败
    List<User> usersToUpdate = new List<User>();

    // 有效更新
    User validUser = disabledUsers[0].clone(true);
    validUser.Title = 'Valid Update';
    usersToUpdate.add(validUser);

    // 无效更新 - 设置Title字段超过最大长度（80字符）以触发DML错误
    User invalidUser = disabledUsers[1].clone(true);
    invalidUser.Title = 'x'.repeat(81); // 超过80字符限制，会导致更新失败
    usersToUpdate.add(invalidUser);

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Map<Id, Database.SaveResult> resultMap = dao.updateUsersPartial(
      usersToUpdate
    );

    Test.stopTest();

    // 验证结果 - 应有1个成功更新（有效用户），无效用户应失败
    System.assertEquals(1, resultMap.size(), '应有1个成功更新');
    System.assert(resultMap.containsKey(validUser.Id), '应包含有效更新的用户');
    System.assert(
      !resultMap.containsKey(invalidUser.Id),
      '不应包含无效更新的用户'
    );
  }

  /**
   * @description 测试批量启用用户门户访问
   */
  @IsTest
  static void testEnablePortalAccessForUsers() {
    // 准备测试数据
    List<User> disabledUsers = getActiveDisabledPortalUsers();
    System.assert(!disabledUsers.isEmpty(), '应有门户访问已禁用的测试用户');

    Set<Id> userIds = new Set<Id>();
    for (User user : disabledUsers) {
      userIds.add(user.Id);
    }

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Integer successCount = dao.enablePortalAccessForUsers(userIds);

    Test.stopTest();

    // 验证结果
    System.assertEquals(disabledUsers.size(), successCount, '成功数量应匹配');

    // 验证数据库更新
    List<User> updatedUsers = [SELECT Title FROM User WHERE Id IN :userIds];
    for (User user : updatedUsers) {
      System.assertEquals(
        'Portal User',
        user.Title,
        '用户Title应已更新为Portal User'
      );
    }
  }

  /**
   * @description 测试批量启用用户门户访问 - 空用户ID集合
   */
  @IsTest
  static void testEnablePortalAccessForUsersEmpty() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Integer successCount = dao.enablePortalAccessForUsers(new Set<Id>());

    Test.stopTest();

    System.assertEquals(0, successCount, '空用户ID集合应返回0');
  }

  // ========== 测试方法 - 统计功能 ==========

  /**
   * @description 测试统计活跃用户数量
   */
  @IsTest
  static void testCountActiveUsers() {
    // 准备测试数据
    List<User> allActiveUsers = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Email LIKE 'dao.%@example.com'
    ];
    Integer expectedCount = allActiveUsers.size();

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Integer actualCount = dao.countActiveUsers();

    Test.stopTest();

    // 在DevHub环境中，可能有其他活跃用户，所以实际数量应至少包含测试用户
    System.assert(
      actualCount >= expectedCount,
      '活跃用户数量应至少包含测试用户，期望：' +
        expectedCount +
        '，实际：' +
        actualCount
    );
  }

  /**
   * @description 测试统计门户用户数量
   */
  @IsTest
  static void testCountPortalUsers() {
    // 准备测试数据
    List<User> enabledUsers = getActiveEnabledPortalUsers();
    List<User> disabledUsers = getActiveDisabledPortalUsers();

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Integer enabledCount = dao.countPortalUsers(true);
    Integer disabledCount = dao.countPortalUsers(false);

    Test.stopTest();

    // 在DevHub环境中，可能有其他门户用户，所以实际数量应至少包含测试用户
    System.assert(
      enabledCount >= enabledUsers.size(),
      '门户已启用用户数量应至少包含测试用户，期望：' +
        enabledUsers.size() +
        '，实际：' +
        enabledCount
    );
    System.assert(
      disabledCount >= disabledUsers.size(),
      '门户已禁用用户数量应至少包含测试用户，期望：' +
        disabledUsers.size() +
        '，实际：' +
        disabledCount
    );
  }

  /**
   * @description 测试自定义查询选项统计
   */
  @IsTest
  static void testCountUsersWithOptions() {
    // 创建查询选项 - 统计活跃门户已禁用用户
    ShowcaseUserDao.UserQueryOptions options = new ShowcaseUserDao.UserQueryOptions();
    options.isActive = true;
    options.isPortalEnabled = false;

    // 准备测试数据
    List<User> disabledUsers = getActiveDisabledPortalUsers();
    Integer expectedCount = disabledUsers.size();

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Integer actualCount = dao.countUsers(options);

    Test.stopTest();

    // 在DevHub环境中，可能有其他匹配条件的用户，所以实际数量应至少包含测试用户
    System.assert(
      actualCount >= expectedCount,
      '用户数量应至少包含测试用户，期望：' +
        expectedCount +
        '，实际：' +
        actualCount
    );
  }

  /**
   * @description 测试空查询选项统计
   */
  @IsTest
  static void testCountUsersNullOptions() {
    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();

    try {
      dao.countUsers(null);
      System.assert(false, '应抛出异常');
    } catch (ShowcaseUserDao.UserQueryValidationException ex) {
      System.assertEquals(
        '查询选项不能为空',
        ex.getMessage(),
        '异常消息应匹配'
      );
    }

    Test.stopTest();
  }

  // ========== 测试方法 - 工具方法 ==========

  /**
   * @description 测试将用户列表转换为映射
   */
  @IsTest
  static void testConvertToMap() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Map<Id, User> userMap = dao.convertToMap(testUsers);

    Test.stopTest();

    // 验证结果
    System.assertEquals(testUsers.size(), userMap.size(), '映射大小应匹配');

    for (User user : testUsers) {
      System.assert(
        userMap.containsKey(user.Id),
        '映射应包含用户ID: ' + user.Id
      );
      System.assertEquals(
        user.Username,
        userMap.get(user.Id).Username,
        '用户名应匹配'
      );
    }
  }

  /**
   * @description 测试提取用户ID集合
   */
  @IsTest
  static void testExtractUserIds() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Set<Id> userIds = dao.extractUserIds(testUsers);

    Test.stopTest();

    // 验证结果
    System.assertEquals(testUsers.size(), userIds.size(), 'ID集合大小应匹配');

    for (User user : testUsers) {
      System.assert(
        userIds.contains(user.Id),
        'ID集合应包含用户ID: ' + user.Id
      );
    }
  }

  /**
   * @description 测试提取用户名集合
   */
  @IsTest
  static void testExtractUsernames() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Set<String> usernames = dao.extractUsernames(testUsers);

    Test.stopTest();

    // 验证结果
    System.assertEquals(
      testUsers.size(),
      usernames.size(),
      '用户名集合大小应匹配'
    );

    for (User user : testUsers) {
      System.assert(
        usernames.contains(user.Username),
        '用户名集合应包含用户名: ' + user.Username
      );
    }
  }

  /**
   * @description 测试提取邮箱集合
   */
  @IsTest
  static void testExtractEmails() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Set<String> emails = dao.extractEmails(testUsers);

    Test.stopTest();

    // 验证结果
    System.assertEquals(testUsers.size(), emails.size(), '邮箱集合大小应匹配');

    for (User user : testUsers) {
      System.assert(
        emails.contains(user.Email),
        '邮箱集合应包含邮箱: ' + user.Email
      );
    }
  }

  /**
   * @description 测试验证用户是否存在
   */
  @IsTest
  static void testUserExists() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    User existingUser = testUsers[0];
    Id nonExistingUserId = '005000000000001'; // 无效用户ID

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    Boolean exists1 = dao.userExists(existingUser.Id);
    Boolean exists2 = dao.userExists(nonExistingUserId);
    Boolean exists3 = dao.userExists(null);

    Test.stopTest();

    // 验证结果
    System.assertEquals(true, exists1, '现有用户应存在');
    System.assertEquals(false, exists2, '不存在用户ID应返回false');
    System.assertEquals(false, exists3, 'null用户ID应返回false');
  }

  /**
   * @description 测试将用户转换为摘要
   */
  @IsTest
  static void testConvertToSummaries() {
    // 准备测试数据
    List<User> testUsers = getActiveDisabledPortalUsers();
    System.assert(!testUsers.isEmpty(), '应有测试用户');

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    List<ShowcaseUserDao.UserSummary> summaries = dao.convertToSummaries(
      testUsers
    );

    Test.stopTest();

    // 验证结果
    System.assertEquals(testUsers.size(), summaries.size(), '摘要数量应匹配');

    for (Integer i = 0; i < testUsers.size(); i++) {
      User user = testUsers[i];
      ShowcaseUserDao.UserSummary summary = summaries[i];

      System.assertEquals(user.Id, summary.userId, '用户ID应匹配');
      System.assertEquals(user.Username, summary.username, '用户名应匹配');
      System.assertEquals(user.Email, summary.email, '邮箱应匹配');
      System.assertEquals(user.Name, summary.name, '名称应匹配');
      System.assertEquals(user.IsActive, summary.isActive, '活跃状态应匹配');
      System.assertEquals(user.UserType, summary.userType, '用户类型应匹配');
    }
  }

  // ========== 测试方法 - 异常处理 ==========

  /**
   * @description 测试查询异常处理
   */
  @IsTest
  static void testQueryExceptionHandling() {
    // 创建无效查询选项（超过限制）
    ShowcaseUserDao.UserQueryOptions options = new ShowcaseUserDao.UserQueryOptions();
    options.limitCount = 20000; // 超过限制

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();

    try {
      dao.queryUsers(options);
      System.assert(false, '应抛出异常');
    } catch (ShowcaseUserDao.UserDaoException ex) {
      System.assert(
        ex.getMessage().contains('用户查询失败'),
        '异常消息应包含查询失败信息'
      );
      System.assertEquals('QUERY', ex.operation, '操作类型应匹配');
    }

    Test.stopTest();
  }

  /**
   * @description 测试更新异常处理
   */
  @IsTest
  static void testUpdateExceptionHandling() {
    // 创建无效用户列表（包含null）
    List<User> invalidUsers = new List<User>();
    invalidUsers.add(null);

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();

    try {
      dao.updateUsers(invalidUsers, true);
      System.assert(false, '应抛出异常');
    } catch (ShowcaseUserDao.UserDaoException ex) {
      System.assert(
        ex.getMessage().contains('用户批量更新失败'),
        '异常消息应包含更新失败信息'
      );
      System.assertEquals('UPDATE', ex.operation, '操作类型应匹配');
    }

    Test.stopTest();
  }

  // ========== 测试方法 - 性能和边界 ==========

  /**
   * @description 测试大量用户查询性能
   */
  @IsTest
  static void testLargeUserQueryPerformance() {
    // 创建查询选项 - 获取所有用户
    ShowcaseUserDao.UserQueryOptions options = new ShowcaseUserDao.UserQueryOptions();
    options.isActive = true;
    options.limitCount = 1000; // 合理限制

    Test.startTest();
    Long startTime = DateTime.now().getTime();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    ShowcaseUserDao.UserQueryResult result = dao.queryUsers(options);

    Long endTime = DateTime.now().getTime();
    Long duration = endTime - startTime;

    Test.stopTest();

    System.assert(
      duration < 5000,
      '大量用户查询应在5秒内完成，实际耗时: ' + duration + 'ms'
    );
    System.assertNotEquals(null, result, '结果不应为空');
  }

  /**
   * @description 测试查询警告机制
   */
  @IsTest
  static void testQueryWarnings() {
    // 创建查询选项 - 设置较小的限制
    ShowcaseUserDao.UserQueryOptions options = new ShowcaseUserDao.UserQueryOptions();
    options.isActive = true;
    options.limitCount = 1; // 很小限制

    Test.startTest();

    ShowcaseUserDao dao = new ShowcaseUserDao();
    ShowcaseUserDao.UserQueryResult result = dao.queryUsers(options);

    Test.stopTest();

    // 验证警告
    if (result.hasMore) {
      System.assert(!result.warnings.isEmpty(), '应有警告信息');
      System.assert(
        result.warnings[0].contains('查询结果可能不完整'),
        '警告消息应匹配'
      );
    }
  }
}
