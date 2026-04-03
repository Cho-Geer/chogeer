@IsTest
private class ShowcaseContactSyncServiceTest {
  private class SuccessMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      System.assertEquals('POST', request.getMethod());
      System.assertEquals(
        'callout:CustomerProfileService/v1/contact-sync',
        request.getEndpoint()
      );

      ShowcaseContactSyncService.ContactSyncRequest payload = (ShowcaseContactSyncService.ContactSyncRequest) JSON.deserialize(
        request.getBody(),
        ShowcaseContactSyncService.ContactSyncRequest.class
      );
      System.assertEquals('Li', payload.lastName);

      HttpResponse response = new HttpResponse();
      response.setStatusCode(202);
      response.setBody(
        '{"success":true,"externalReference":"EXT-2026-0001","message":"Accepted"}'
      );
      return response;
    }
  }

  private class FailureMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(500);
      response.setBody(
        '{"success":false,"message":"Remote system unavailable"}'
      );
      return response;
    }
  }

  @IsTest
  static void returnsParsedSuccessResponse() {
    ShowcaseContactSyncService.ContactSyncRequest payload = new ShowcaseContactSyncService.ContactSyncRequest();
    payload.contactId = '003000000000001AAA';
    payload.firstName = 'Ava';
    payload.lastName = 'Li';
    payload.email = 'ava.li@example.com';
    payload.title = 'Integration Lead';

    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    Test.startTest();
    ShowcaseContactSyncService.ContactSyncResult result = ShowcaseContactSyncService.syncContact(
      payload
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(202, result.statusCode);
    System.assertEquals('EXT-2026-0001', result.externalReference);
  }

  @IsTest
  static void throwsWhenRemoteServiceFails() {
    ShowcaseContactSyncService.ContactSyncRequest payload = new ShowcaseContactSyncService.ContactSyncRequest();
    payload.lastName = 'Li';

    Test.setMock(HttpCalloutMock.class, new FailureMock());

    try {
      ShowcaseContactSyncService.syncContact(payload);
      System.assert(false, 'Expected a callout failure exception.');
    } catch (ShowcaseContactSyncService.CalloutFailureException ex) {
      System.assertEquals('Remote system unavailable', ex.getMessage());
    }
  }

  @IsTest
  static void validatesRequiredPayload() {
    try {
      ShowcaseContactSyncService.syncContact(
        new ShowcaseContactSyncService.ContactSyncRequest()
      );
      System.assert(false, 'Expected a configuration exception.');
    } catch (ShowcaseContactSyncService.CalloutConfigurationException ex) {
      System.assertEquals(
        'Last name is required for the outbound sync.',
        ex.getMessage()
      );
    }
  }
}
