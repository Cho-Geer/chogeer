/**
 * @description 测试用虚拟服务类 - 用于演示Mock框架
 * 提供多种方法签名，支持参数匹配、异常抛出、返回值配置等测试场景
 */
public virtual class TestService {
  public virtual String getGreeting(String name) {
    return null;
  }
  public virtual Integer calculateTotal(List<Integer> numbers) {
    return null;
  }
  public virtual Boolean validateEmail(String email) {
    return null;
  }
  public virtual List<String> getItems(Integer count) {
    return null;
  }
  public virtual Map<String, Object> getConfig() {
    return null;
  }
  public virtual void processItem(String item) {
  }
  public virtual String getDataWithParams(
    String param1,
    Integer param2,
    Boolean param3
  ) {
    return null;
  }

  // 重载方法支持
  public virtual String processData(String input) {
    return null;
  }
  public virtual String processData(String input, Integer count) {
    return null;
  }

  // 复杂返回值方法
  public virtual List<Map<String, Object>> getComplexData() {
    return null;
  }

  // 抛出异常的方法
  public virtual void throwException() {
  }
}
