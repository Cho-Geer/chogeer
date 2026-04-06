@IsTest
public class ShowcaseMockProviderTest {
  public interface TestService {
    String getGreeting(String name);
    Map<String, Object> getConfig();
    Integer calculate(Integer a, Integer b);
  }

  @IsTest
  static void testBasicMock() {
    ShowcaseMockProvider mockProvider = new ShowcaseMockProvider();

    mockProvider.when('getGreeting', String.class).thenReturn('Hello');

    TestService mockService = (TestService) Test.createStub(
      TestService.class,
      mockProvider
    );

    Test.startTest();
    String result = mockService.getGreeting('World');
    Test.stopTest();

    System.assertEquals('Hello', result, 'Should return mocked greeting');
    System.assertEquals(
      1,
      mockProvider.getCallCount('getGreeting'),
      'Should record 1 call'
    );
  }

  @IsTest
  static void testMethodWithDifferentReturnTypes() {
    ShowcaseMockProvider mockProvider = new ShowcaseMockProvider();

    mockProvider.when('getConfig', Map<String, Object>.class)
      .thenReturn(new Map<String, Object>{ 'test' => 'value' });

    mockProvider.when('calculate', Integer.class).thenReturn(42);

    TestService mockService = (TestService) Test.createStub(
      TestService.class,
      mockProvider
    );

    Test.startTest();
    Map<String, Object> configResult = mockService.getConfig();
    Integer calcResult = mockService.calculate(10, 20);
    Test.stopTest();

    System.assertEquals(
      'value',
      configResult.get('test'),
      'Should return mocked config'
    );
    System.assertEquals(42, calcResult, 'Should return mocked calculation');
  }

  @IsTest
  static void testCallCountAndReset() {
    ShowcaseMockProvider mockProvider = new ShowcaseMockProvider();

    mockProvider.when('getGreeting', String.class).thenReturn('Hi');

    TestService mockService = (TestService) Test.createStub(
      TestService.class,
      mockProvider
    );

    Test.startTest();
    mockService.getGreeting('Alice');
    mockService.getGreeting('Bob');
    mockService.getGreeting('Charlie');
    Test.stopTest();

    System.assertEquals(
      3,
      mockProvider.getCallCount('getGreeting'),
      'Should record 3 calls'
    );

    mockProvider.reset();
    System.assertEquals(
      0,
      mockProvider.getCallCount('getGreeting'),
      'Should reset call count'
    );
  }

  @IsTest
  static void testExceptionThrowing() {
    ShowcaseMockProvider mockProvider = new ShowcaseMockProvider();

    mockProvider.when('calculate', Integer.class)
      .thenThrow(new MockProviderTestException('Test exception'));

    TestService mockService = (TestService) Test.createStub(
      TestService.class,
      mockProvider
    );

    Test.startTest();
    try {
      Integer result = mockService.calculate(1, 2);
      System.assert(false, 'Should have thrown exception');
    } catch (MockProviderTestException e) {
      System.assertEquals(
        'Test exception',
        e.getMessage(),
        'Should throw expected exception'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testArgumentCapturing() {
    ShowcaseMockProvider mockProvider = new ShowcaseMockProvider();

    ShowcaseMockProvider.MethodConfig config = mockProvider.when(
        'getGreeting',
        String.class
      )
      .thenReturn('Hello')
      .expectCallCount(3);

    TestService mockService = (TestService) Test.createStub(
      TestService.class,
      mockProvider
    );

    Test.startTest();
    mockService.getGreeting('Alice');
    mockService.getGreeting('Bob');
    mockService.getGreeting('Charlie');
    Test.stopTest();

    System.assertEquals(3, config.actualCallCount, 'Should call 3 times');
    System.assertEquals(
      3,
      config.capturedArgs.size(),
      'Should capture 3 arguments'
    );

    List<Object> lastArgs = config.getLastCallArgs();
    System.assertEquals(1, lastArgs.size(), 'Last call should have 1 argument');
    System.assertEquals(
      'Charlie',
      lastArgs[0],
      'Last argument should be Charlie'
    );
  }

  @IsTest
  static void testPerformance() {
    ShowcaseMockProvider mockProvider = new ShowcaseMockProvider();

    mockProvider.when('getGreeting', String.class).thenReturn('Hello');

    TestService mockService = (TestService) Test.createStub(
      TestService.class,
      mockProvider
    );

    Test.startTest();
    Long startTime = DateTime.now().getTime();

    for (Integer i = 0; i < 100; i++) {
      String result = mockService.getGreeting('User' + i);
      System.assertEquals(
        'Hello',
        result,
        'Should return same value for each call'
      );
    }

    Long endTime = DateTime.now().getTime();
    Long duration = endTime - startTime;
    Test.stopTest();

    System.assertEquals(
      100,
      mockProvider.getCallCount('getGreeting'),
      'Should call 100 times'
    );
    System.assert(
      duration < 1000,
      '100 calls should complete within 1 second, actual: ' + duration + 'ms'
    );
  }

  public class MockProviderTestException extends Exception {
  }
}
