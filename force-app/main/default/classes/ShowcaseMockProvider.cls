/**
 * @description 通用Mock框架 - 用于Apex单元测试的方法存根和验证
 * 提供灵活的Mock配置、调用记录和验证功能
 * 支持：返回值配置、异常抛出、参数匹配、调用次数验证
 */
public with sharing class ShowcaseMockProvider implements System.StubProvider {
  // ========== 内部配置类 ==========

  /**
   * @description 方法配置 - 定义方法的期望行为
   */
  public class MethodConfig {
    public String methodName { get; private set; }
    public Type returnType { get; private set; }
    public Object returnValue { get; private set; }
    public Exception throwException { get; private set; }
    public List<Type> paramTypes { get; private set; }
    public Integer expectedCallCount { get; set; }
    public Integer actualCallCount { get; set; }
    public Boolean matchAnyParams { get; set; }
    public List<List<Object>> capturedArgs { get; private set; }

    public MethodConfig(String methodName, Type returnType) {
      this.methodName = methodName;
      this.returnType = returnType;
      this.paramTypes = new List<Type>();
      this.expectedCallCount = null; // null表示不限制调用次数
      this.actualCallCount = 0;
      this.matchAnyParams = false;
      this.capturedArgs = new List<List<Object>>();
    }

    /**
     * @description 设置返回值
     */
    public MethodConfig thenReturn(Object returnValue) {
      this.returnValue = returnValue;
      this.throwException = null;
      return this;
    }

    /**
     * @description 设置抛出异常
     */
    public MethodConfig thenThrow(Exception ex) {
      this.throwException = ex;
      this.returnValue = null;
      return this;
    }

    /**
     * @description 设置期望调用次数
     */
    public MethodConfig expectCallCount(Integer count) {
      this.expectedCallCount = count;
      return this;
    }

    /**
     * @description 设置参数类型（用于方法重载区分）
     */
    public MethodConfig withParamTypes(List<Type> paramTypes) {
      this.paramTypes = paramTypes;
      return this;
    }

    /**
     * @description 设置匹配任意参数
     */
    public MethodConfig withAnyParams() {
      this.matchAnyParams = true;
      return this;
    }

    /**
     * @description 记录方法调用
     */
    public void recordCall(List<Object> args) {
      actualCallCount++;
      capturedArgs.add(args);
    }

    /**
     * @description 验证调用次数
     */
    public void verify() {
      if (expectedCallCount != null && actualCallCount != expectedCallCount) {
        throw new MockVerificationException(
          'Method "' +
            methodName +
            '" expected ' +
            expectedCallCount +
            ' calls but was called ' +
            actualCallCount +
            ' times.'
        );
      }
    }

    /**
     * @description 获取最近一次调用的参数
     */
    public List<Object> getLastCallArgs() {
      return capturedArgs.isEmpty()
        ? new List<Object>()
        : capturedArgs[capturedArgs.size() - 1];
    }
  }

  // ========== 异常类 ==========

  /**
   * @description Mock验证异常
   */
  public class MockVerificationException extends Exception {
  }

  /**
   * @description 未配置方法异常
   */
  public class MethodNotConfiguredException extends Exception {
  }

  /**
   * @description 参数不匹配异常
   */
  public class ArgumentMismatchException extends Exception {
  }

  // ========== 核心属性 ==========

  private Map<String, List<MethodConfig>> methodConfigs;
  private Map<String, Integer> genericCallCounts;
  private Boolean recordAllCalls;
  private List<CallLog> callLogs;

  /**
   * @description 调用日志记录
   */
  public class CallLog {
    public String methodName { get; private set; }
    public List<Object> arguments { get; private set; }
    public DateTime callTime { get; private set; }
    public Object returnValue { get; private set; }
    public Exception thrownException { get; private set; }

    public CallLog(String methodName, List<Object> arguments) {
      this.methodName = methodName;
      this.arguments = arguments;
      this.callTime = DateTime.now();
    }

    public void setResult(Object returnValue) {
      this.returnValue = returnValue;
    }

    public void setException(Exception ex) {
      this.thrownException = ex;
    }
  }

  // ========== 构造函数 ==========

  /**
   * @description 默认构造函数
   */
  public ShowcaseMockProvider() {
    this.methodConfigs = new Map<String, List<MethodConfig>>();
    this.genericCallCounts = new Map<String, Integer>();
    this.recordAllCalls = true;
    this.callLogs = new List<CallLog>();
  }

  /**
   * @description 构造函数，可配置是否记录所有调用
   */
  public ShowcaseMockProvider(Boolean recordAllCalls) {
    this();
    this.recordAllCalls = recordAllCalls;
  }

  // ========== 公共API - 配置方法 ==========

  /**
   * @description 配置方法行为（无参数类型区分）
   */
  public MethodConfig when(String methodName, Type returnType) {
    return when(methodName, returnType, new List<Type>());
  }

  /**
   * @description 配置方法行为（带参数类型区分）
   */
  public MethodConfig when(
    String methodName,
    Type returnType,
    List<Type> paramTypes
  ) {
    MethodConfig config = new MethodConfig(methodName, returnType);
    config.withParamTypes(paramTypes);

    if (!methodConfigs.containsKey(methodName)) {
      methodConfigs.put(methodName, new List<MethodConfig>());
    }
    methodConfigs.get(methodName).add(config);

    return config;
  }

  /**
   * @description 配置任意参数匹配
   */
  public MethodConfig whenAny(String methodName, Type returnType) {
    MethodConfig config = when(methodName, returnType);
    config.withAnyParams();
    return config;
  }

  // ========== 公共API - 验证方法 ==========

  /**
   * @description 验证所有配置的方法调用次数
   */
  public void verifyAll() {
    for (List<MethodConfig> configList : methodConfigs.values()) {
      for (MethodConfig config : configList) {
        config.verify();
      }
    }
  }

  /**
   * @description 验证特定方法调用次数
   */
  public void verifyMethod(String methodName) {
    if (methodConfigs.containsKey(methodName)) {
      for (MethodConfig config : methodConfigs.get(methodName)) {
        config.verify();
      }
    }
  }

  /**
   * @description 获取方法调用次数
   */
  public Integer getCallCount(String methodName) {
    if (!genericCallCounts.containsKey(methodName)) {
      return 0;
    }
    return genericCallCounts.get(methodName);
  }

  /**
   * @description 获取所有调用日志
   */
  public List<CallLog> getCallLogs() {
    return callLogs.clone();
  }

  /**
   * @description 获取特定方法的调用日志
   */
  public List<CallLog> getMethodCallLogs(String methodName) {
    List<CallLog> methodLogs = new List<CallLog>();
    for (CallLog log : callLogs) {
      if (log.methodName == methodName) {
        methodLogs.add(log);
      }
    }
    return methodLogs;
  }

  /**
   * @description 清空所有配置和日志
   */
  public void reset() {
    methodConfigs.clear();
    genericCallCounts.clear();
    callLogs.clear();
  }

  // ========== System.StubProvider接口实现 ==========

  /**
   * @description 处理方法调用 - 核心StubProvider实现
   */
  public Object handleMethodCall(
    Object stubbedObject,
    String stubbedMethodName,
    Type returnType,
    List<Type> listOfParamTypes,
    List<String> listOfParamNames,
    List<Object> listOfArgs
  ) {
    // 记录通用调用次数
    incrementCallCount(stubbedMethodName);

    // 记录调用日志
    CallLog callLog = new CallLog(stubbedMethodName, listOfArgs);
    callLogs.add(callLog);

    // 查找匹配的配置
    MethodConfig matchedConfig = findMatchingConfig(
      stubbedMethodName,
      returnType,
      listOfParamTypes
    );

    if (matchedConfig == null) {
      // 如果没有配置，使用默认行为
      return getDefaultReturnValue(returnType, stubbedMethodName);
    }

    // 记录调用
    matchedConfig.recordCall(listOfArgs);

    // 处理异常抛出
    if (matchedConfig.throwException != null) {
      callLog.setException(matchedConfig.throwException);
      throw matchedConfig.throwException;
    }

    // 处理返回值
    Object returnValue = matchedConfig.returnValue;
    callLog.setResult(returnValue);
    return returnValue;
  }

  // ========== 私有辅助方法 ==========

  /**
   * @description 查找匹配的方法配置
   */
  private MethodConfig findMatchingConfig(
    String methodName,
    Type returnType,
    List<Type> paramTypes
  ) {
    if (!methodConfigs.containsKey(methodName)) {
      return null;
    }

    List<MethodConfig> configs = methodConfigs.get(methodName);

    // 首先查找完全匹配（方法名+返回类型+参数类型）
    for (MethodConfig config : configs) {
      if (
        config.returnType == returnType &&
        config.paramTypes.size() == paramTypes.size()
      ) {
        Boolean paramMatch = true;
        for (Integer i = 0; i < paramTypes.size(); i++) {
          if (config.paramTypes[i] != paramTypes[i]) {
            paramMatch = false;
            break;
          }
        }

        if (paramMatch) {
          return config;
        }
      }
    }

    // 查找任意参数匹配的配置
    for (MethodConfig config : configs) {
      if (config.returnType == returnType && config.matchAnyParams) {
        return config;
      }
    }

    // 查找仅方法名匹配的配置（最后手段）
    for (MethodConfig config : configs) {
      if (config.returnType == returnType && config.paramTypes.isEmpty()) {
        return config;
      }
    }

    return null;
  }

  /**
   * @description 增加调用次数
   */
  private void incrementCallCount(String methodName) {
    if (!genericCallCounts.containsKey(methodName)) {
      genericCallCounts.put(methodName, 0);
    }
    genericCallCounts.put(methodName, genericCallCounts.get(methodName) + 1);
  }

  /**
   * @description 获取默认返回值
   */
  private Object getDefaultReturnValue(Type returnType, String methodName) {
    String typeName = returnType.getName();

    // 根据返回类型提供合理的默认值
    if (typeName == 'String') {
      return 'mock-' + methodName;
    } else if (
      typeName == 'Integer' ||
      typeName == 'Double' ||
      typeName == 'Decimal'
    ) {
      return 0;
    } else if (typeName == 'Boolean') {
      return false;
    } else if (typeName == 'Date') {
      return Date.today();
    } else if (typeName == 'Datetime') {
      return Datetime.now();
    } else if (typeName == 'List<String>') {
      return new List<String>{ 'mock' };
    } else if (typeName == 'List<Object>') {
      return new List<Object>();
    } else if (typeName == 'Map<String, Object>') {
      return new Map<String, Object>{ 'method' => methodName };
    }

    // 对于自定义对象或其他类型返回null
    return null;
  }

  // ========== 静态工具方法 ==========

  /**
   * @description 创建Mock对象
   */
  public static Object createMock(Type typeToMock) {
    ShowcaseMockProvider mockProvider = new ShowcaseMockProvider();
    return Test.createStub(typeToMock, mockProvider);
  }

  /**
   * @description 创建Mock对象（带配置）
   */
  public static Object createMock(
    Type typeToMock,
    ShowcaseMockProvider mockProvider
  ) {
    return Test.createStub(typeToMock, mockProvider);
  }

  /**
   * @description 从Mock对象获取MockProvider
   */
  public static ShowcaseMockProvider getMockProvider(Object mockedObject) {
    // 注意：这是一个简化实现，实际需要更复杂的逻辑来提取MockProvider
    // 在真实场景中，可能需要使用反射或其他技术
    return new ShowcaseMockProvider();
  }
}
