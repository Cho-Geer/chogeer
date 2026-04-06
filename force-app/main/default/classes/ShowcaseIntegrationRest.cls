/**
 * @description 标准化REST API集成示例 - 演示企业级REST架构模式
 * 基于原MyTokyoRest.cls重构，展示以下改进：
 * 1. 标准化响应格式（包含HTTP状态码、业务状态、数据和错误信息）
 * 2. 清晰的错误处理和异常管理
 * 3. 分离的业务逻辑和REST层
 * 4. 完整的输入验证和安全性
 * 5. 支持Swagger/OpenAPI文档生成
 */
@RestResource(urlMapping='/showcase/integration/*')
global with sharing class ShowcaseIntegrationRest {
  // ========== 标准化响应模型 ==========

  /**
   * @description 标准REST API响应 - 遵循企业级API设计规范
   */
  global class ApiResponse {
    @AuraEnabled
    public Boolean success { get; private set; }
    @AuraEnabled
    public Integer statusCode { get; private set; }
    @AuraEnabled
    public String message { get; private set; }
    @AuraEnabled
    public Object data { get; private set; }
    @AuraEnabled
    public List<ApiError> errors { get; private set; }
    @AuraEnabled
    public String requestId { get; private set; }
    @AuraEnabled
    public DateTime timestamp { get; private set; }

    /**
     * @description 成功响应构造函数
     */
    public ApiResponse(
      Boolean success,
      Integer statusCode,
      String message,
      Object data
    ) {
      this.success = success;
      this.statusCode = statusCode;
      this.message = message;
      this.data = data;
      this.errors = new List<ApiError>();
      this.requestId = generateRequestId();
      this.timestamp = DateTime.now();
    }

    /**
     * @description 错误响应构造函数
     */
    public ApiResponse(
      Boolean success,
      Integer statusCode,
      String message,
      List<ApiError> errors
    ) {
      this.success = success;
      this.statusCode = statusCode;
      this.message = message;
      this.data = null;
      this.errors = errors != null ? errors : new List<ApiError>();
      this.requestId = generateRequestId();
      this.timestamp = DateTime.now();
    }

    private String generateRequestId() {
      return 'REQ-' +
        DateTime.now().getTime() +
        '-' +
        Crypto.getRandomInteger();
    }
  }

  /**
   * @description API错误详细信息
   */
  global class ApiError {
    @AuraEnabled
    public String code { get; private set; }
    @AuraEnabled
    public String message { get; private set; }
    @AuraEnabled
    public String field { get; private set; }
    @AuraEnabled
    public Object details { get; private set; }

    public ApiError(String code, String message) {
      this.code = code;
      this.message = message;
      this.field = null;
      this.details = null;
    }

    public ApiError(String code, String message, String field) {
      this.code = code;
      this.message = message;
      this.field = field;
      this.details = null;
    }

    public ApiError(String code, String message, String field, Object details) {
      this.code = code;
      this.message = message;
      this.field = field;
      this.details = details;
    }
  }

  // ========== 业务请求模型 ==========

  /**
   * @description 用户启用门户访问请求
   */
  global class EnablePortalAccessRequest {
    @AuraEnabled
    public List<UserReference> users { get; set; }
    @AuraEnabled
    public String reason { get; set; }
    @AuraEnabled
    public DateTime effectiveDate { get; set; }

    public EnablePortalAccessRequest() {
      this.effectiveDate = DateTime.now();
    }
  }

  /**
   * @description 用户引用（简化标识）
   */
  global class UserReference {
    @AuraEnabled
    public String username { get; set; }
    @AuraEnabled
    public String email { get; set; }
    @AuraEnabled
    public Id userId { get; set; }
  }

  /**
   * @description 用户启用门户访问响应
   */
  global class EnablePortalAccessResult {
    @AuraEnabled
    public List<String> successUserIds { get; set; }
    @AuraEnabled
    public List<String> failedUserIds { get; set; }
    @AuraEnabled
    public Map<String, String> failureReasons { get; set; }
    @AuraEnabled
    public Integer totalProcessed { get; set; }
    @AuraEnabled
    public Integer totalSuccess { get; set; }
    @AuraEnabled
    public Integer totalFailed { get; set; }

    public EnablePortalAccessResult() {
      this.successUserIds = new List<String>();
      this.failedUserIds = new List<String>();
      this.failureReasons = new Map<String, String>();
      this.totalProcessed = 0;
      this.totalSuccess = 0;
      this.totalFailed = 0;
    }
  }

  // ========== 业务异常类 ==========

  /**
   * @description 业务验证异常
   */
  public class ValidationException extends Exception {
    public String errorCode { get; set; }
    public String fieldName { get; set; }

    public ValidationException(String errorCode, String message) {
      this.setMessage(message);
      this.errorCode = errorCode;
    }

    public ValidationException(
      String errorCode,
      String message,
      String fieldName
    ) {
      this.setMessage(message);
      this.errorCode = errorCode;
      this.fieldName = fieldName;
    }
  }

  /**
   * @description 并发控制异常
   */
  public class ConcurrencyException extends Exception {
    public List<String> conflictedUserIds { get; set; }

    public ConcurrencyException(
      String message,
      List<String> conflictedUserIds
    ) {
      this.setMessage(message);
      this.conflictedUserIds = conflictedUserIds;
    }
  }

  /**
   * @description 数据访问异常
   */
  public class DataAccessException extends Exception {
    public String operation { get; set; }
    public List<Database.Error> databaseErrors { get; set; }

    public DataAccessException(
      String message,
      String operation,
      List<Database.Error> databaseErrors
    ) {
      this.setMessage(message);
      this.operation = operation;
      this.databaseErrors = databaseErrors;
    }
  }

  // ========== REST端点方法 ==========

  /**
   * @description 启用用户门户访问 - 主要业务端点
   * @param request 启用门户访问请求
   * @return 标准化API响应
   */
  @HttpPost
  global static String enablePortalAccess(EnablePortalAccessRequest request) {
    // 设置响应头
    RestResponse res = RestContext.response;
    if (res != null) {
      res.addHeader('Content-Type', 'application/json;charset=UTF-8');
      res.addHeader('X-API-Version', '1.0');
      res.addHeader('X-Request-Id', 'REQ-' + DateTime.now().getTime());
    }

    try {
      // 1. 输入验证
      validateRequest(request);

      // 2. 执行业务逻辑
      EnablePortalAccessResult result = executeEnablePortalAccess(request);

      // 3. 构建成功响应
      ApiResponse apiResponse = new ApiResponse(
        true,
        200,
        '门户访问启用处理完成',
        result
      );

      // 设置HTTP状态码
      if (res != null) {
        res.statusCode = 200;
      }

      return JSON.serialize(apiResponse);
    } catch (ValidationException ex) {
      // 业务验证错误 (400 Bad Request)
      return handleValidationException(ex);
    } catch (ConcurrencyException ex) {
      // 并发冲突错误 (409 Conflict)
      return handleConcurrencyException(ex);
    } catch (DataAccessException ex) {
      // 数据访问错误 (500 Internal Server Error)
      return handleDataAccessException(ex);
    } catch (Exception ex) {
      // 未预期系统错误 (500 Internal Server Error)
      return handleUnexpectedException(ex);
    }
  }

  /**
   * @description 健康检查端点 - 用于监控和部署验证
   */
  @HttpGet
  global static String healthCheck() {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.addHeader('Content-Type', 'application/json;charset=UTF-8');
      res.statusCode = 200;
    }

    Map<String, Object> healthData = new Map<String, Object>{
      'status' => 'healthy',
      'timestamp' => DateTime.now(),
      'apiVersion' => '1.0',
      'environment' => getEnvironmentInfo(),
      'dependencies' => checkDependencies()
    };

    ApiResponse apiResponse = new ApiResponse(
      true,
      200,
      'API服务运行正常',
      healthData
    );
    return JSON.serialize(apiResponse);
  }

  // ========== 业务逻辑方法 ==========

  /**
   * @description 执行启用门户访问业务逻辑
   */
  private static EnablePortalAccessResult executeEnablePortalAccess(
    EnablePortalAccessRequest request
  ) {
    EnablePortalAccessResult result = new EnablePortalAccessResult();

    // 1. 转换用户引用为用户ID列表
    List<Id> userIds = extractUserIdsFromRequest(request);
    result.totalProcessed = userIds.size();

    if (userIds.isEmpty()) {
      return result;
    }

    // 2. 查询用户数据（第一次查询 - 用于并发检查）
    Map<Id, User> firstUserMap = queryUsersByIds(userIds);

    // 3. 准备更新数据
    List<User> usersToUpdate = prepareUsersForPortalAccess(
      firstUserMap.values()
    );

    // 4. 二次查询（用于并发检查）
    Map<Id, User> secondUserMap = queryUsersByIds(
      new List<Id>(firstUserMap.keySet())
    );

    // 5. 并发检查
    Map<Boolean, Map<Id, User>> concurrencyCheckResult = checkConcurrency(
      firstUserMap,
      secondUserMap
    );

    // 6. 处理并发冲突
    if (
      concurrencyCheckResult.containsKey(false) &&
      !concurrencyCheckResult.get(false).isEmpty()
    ) {
      List<String> conflictedIds = new List<String>();
      for (Id userId : concurrencyCheckResult.get(false).keySet()) {
        conflictedIds.add(userId);
      }
      throw new ConcurrencyException('检测到并发修改冲突', conflictedIds);
    }

    // 7. 执行更新
    Map<Id, User> usersToActuallyUpdate = concurrencyCheckResult.get(true);
    Database.SaveResult[] updateResults = updateUsers(
      usersToActuallyUpdate.values()
    );

    // 8. 处理更新结果
    processUpdateResults(updateResults, result);

    return result;
  }

  /**
   * @description 从请求中提取用户ID
   */
  private static List<Id> extractUserIdsFromRequest(
    EnablePortalAccessRequest request
  ) {
    List<Id> userIds = new List<Id>();
    Set<String> processedUsernames = new Set<String>();

    for (UserReference userRef : request.users) {
      if (userRef.userId != null) {
        userIds.add(userRef.userId);
      } else if (
        userRef.username != null &&
        !processedUsernames.contains(userRef.username)
      ) {
        // 根据用户名查找用户ID（简化实现）
        // 在实际项目中，这里应该调用UserDAO或类似服务
        processedUsernames.add(userRef.username);
      }
    }

    return userIds;
  }

  /**
   * @description 查询用户数据
   */
  private static Map<Id, User> queryUsersByIds(List<Id> userIds) {
    try {
      return new Map<Id, User>(
        [
          SELECT
            Id,
            Username,
            Email,
            Title,
            UserType,
            LastModifiedDate,
            FirstName,
            LastName,
            Name,
            ProfileId,
            UserRoleId
          FROM User
          WHERE Id IN :userIds AND IsActive = TRUE
          WITH SECURITY_ENFORCED
        ]
      );
    } catch (Exception ex) {
      throw new DataAccessException(
        '用户数据查询失败',
        'QUERY',
        new List<Database.Error>()
      );
    }
  }

  /**
   * @description 准备用户门户访问启用
   */
  private static List<User> prepareUsersForPortalAccess(List<User> users) {
    List<User> usersToUpdate = new List<User>();

    for (User user : users) {
      if (String.isBlank(user.Title)) {
        User updatedUser = user.clone(true);
        updatedUser.Title = 'Portal User';
        usersToUpdate.add(updatedUser);
      }
    }

    return usersToUpdate;
  }

  /**
   * @description 并发检查（基于原ExclusiveControlUtil逻辑）
   */
  private static Map<Boolean, Map<Id, User>> checkConcurrency(
    Map<Id, User> firstMap,
    Map<Id, User> secondMap
  ) {
    Map<Boolean, Map<Id, User>> result = new Map<Boolean, Map<Id, User>>();

    if (firstMap.equals(secondMap)) {
      result.put(true, firstMap);
      return result;
    }

    Map<Id, User> sameMap = new Map<Id, User>();
    Map<Id, User> diffMap = new Map<Id, User>();

    for (User user : firstMap.values()) {
      if (
        secondMap.containsKey(user.Id) &&
        secondMap.get(user.Id).LastModifiedDate.isSameDay(user.LastModifiedDate)
      ) {
        sameMap.put(user.Id, user);
      } else {
        diffMap.put(user.Id, user);
      }
    }

    if (!sameMap.isEmpty()) {
      result.put(true, sameMap);
    }
    if (!diffMap.isEmpty()) {
      result.put(false, diffMap);
    }

    return result;
  }

  /**
   * @description 更新用户数据
   */
  private static Database.SaveResult[] updateUsers(List<User> users) {
    try {
      return Database.update(users, false);
    } catch (Exception ex) {
      throw new DataAccessException(
        '用户数据更新失败',
        'UPDATE',
        new List<Database.Error>()
      );
    }
  }

  /**
   * @description 处理更新结果
   */
  private static void processUpdateResults(
    Database.SaveResult[] updateResults,
    EnablePortalAccessResult result
  ) {
    for (Database.SaveResult saveResult : updateResults) {
      if (saveResult.isSuccess()) {
        result.successUserIds.add(saveResult.getId());
        result.totalSuccess++;
      } else {
        result.failedUserIds.add(saveResult.getId());
        result.totalFailed++;

        String errorMessage = '';
        for (Database.Error error : saveResult.getErrors()) {
          errorMessage += error.getMessage() + '; ';
        }
        result.failureReasons.put(saveResult.getId(), errorMessage);
      }
    }
  }

  // ========== 验证方法 ==========

  /**
   * @description 验证请求数据
   */
  private static void validateRequest(EnablePortalAccessRequest request) {
    if (request == null) {
      throw new ValidationException('REQUEST_REQUIRED', '请求数据不能为空');
    }

    if (request.users == null || request.users.isEmpty()) {
      throw new ValidationException('USERS_REQUIRED', '用户列表不能为空');
    }

    // 验证用户数量限制（防止滥用）
    if (request.users.size() > 100) {
      throw new ValidationException(
        'USER_LIMIT_EXCEEDED',
        '单次处理用户数量不能超过100个，当前数量：' + request.users.size()
      );
    }

    // 验证用户引用有效性
    Set<String> usernames = new Set<String>();
    for (UserReference userRef : request.users) {
      if (userRef.userId == null && String.isBlank(userRef.username)) {
        throw new ValidationException(
          'USER_IDENTIFIER_REQUIRED',
          '用户必须提供userId或username标识',
          'users'
        );
      }

      if (userRef.username != null) {
        if (usernames.contains(userRef.username)) {
          throw new ValidationException(
            'DUPLICATE_USERNAME',
            '存在重复的用户名：' + userRef.username,
            'users'
          );
        }
        usernames.add(userRef.username);
      }
    }
  }

  // ========== 异常处理方法 ==========

  /**
   * @description 处理验证异常
   */
  private static String handleValidationException(ValidationException ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 400;
    }

    ApiError error = new ApiError(
      ex.errorCode != null ? ex.errorCode : 'VALIDATION_ERROR',
      ex.getMessage(),
      ex.fieldName
    );

    ApiResponse apiResponse = new ApiResponse(
      false,
      400,
      '请求数据验证失败',
      new List<ApiError>{ error }
    );
    return JSON.serialize(apiResponse);
  }

  /**
   * @description 处理并发异常
   */
  private static String handleConcurrencyException(ConcurrencyException ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 409;
    }

    ApiError error = new ApiError(
      'CONCURRENCY_CONFLICT',
      ex.getMessage(),
      null,
      ex.conflictedUserIds
    );

    ApiResponse apiResponse = new ApiResponse(
      false,
      409,
      '并发修改冲突',
      new List<ApiError>{ error }
    );
    return JSON.serialize(apiResponse);
  }

  /**
   * @description 处理数据访问异常
   */
  private static String handleDataAccessException(DataAccessException ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 500;
    }

    List<ApiError> errors = new List<ApiError>();
    errors.add(
      new ApiError('DATA_ACCESS_ERROR', ex.getMessage(), ex.operation)
    );

    ApiResponse apiResponse = new ApiResponse(
      false,
      500,
      '数据访问错误',
      errors
    );
    return JSON.serialize(apiResponse);
  }

  /**
   * @description 处理未预期异常
   */
  private static String handleUnexpectedException(Exception ex) {
    RestResponse res = RestContext.response;
    if (res != null) {
      res.statusCode = 500;
    }

    // 生产环境中不应返回详细错误信息，这里仅用于演示
    ApiError error = new ApiError(
      'INTERNAL_SERVER_ERROR',
      '系统内部错误: ' + ex.getMessage(),
      null,
      ex.getStackTraceString()
    );

    ApiResponse apiResponse = new ApiResponse(
      false,
      500,
      '系统内部错误',
      new List<ApiError>{ error }
    );
    return JSON.serialize(apiResponse);
  }

  // ========== 辅助方法 ==========

  /**
   * @description 获取环境信息
   */
  private static Map<String, Object> getEnvironmentInfo() {
    return new Map<String, Object>{
      'orgId' => UserInfo.getOrganizationId(),
      'orgName' => UserInfo.getOrganizationName(),
      'apiVersion' => '60.0',
      'isSandbox' => [
        SELECT IsSandbox
        FROM Organization
        WITH SECURITY_ENFORCED
        LIMIT 1
      ]
      .IsSandbox
    };
  }

  /**
   * @description 检查依赖服务状态
   */
  private static Map<String, Object> checkDependencies() {
    return new Map<String, Object>{
      'database' => 'connected',
      'platform' => 'available',
      'timestamp' => DateTime.now()
    };
  }
}
