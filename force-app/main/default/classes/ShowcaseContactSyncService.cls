public with sharing class ShowcaseContactSyncService {
  @TestVisible
  private static final String NAMED_CREDENTIAL = 'CustomerProfileService';

  @TestVisible
  private static final String RESOURCE_PATH = '/v1/contact-sync';

  public class ContactSyncRequest {
    public Id contactId;
    public String firstName;
    public String lastName;
    public String email;
    public String title;
  }

  public class ContactSyncResult {
    public Boolean success;
    public Integer statusCode;
    public String externalReference;
    public String message;
  }

  public class CalloutConfigurationException extends Exception {
  }
  public class CalloutFailureException extends Exception {
  }

  public static ContactSyncResult syncContact(ContactSyncRequest payload) {
    if (payload == null) {
      throw new CalloutConfigurationException('A contact payload is required.');
    }
    if (String.isBlank(payload.lastName)) {
      throw new CalloutConfigurationException(
        'Last name is required for the outbound sync.'
      );
    }

    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:' + NAMED_CREDENTIAL + RESOURCE_PATH);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setTimeout(10000);
    request.setBody(JSON.serialize(payload));

    HttpResponse response = new Http().send(request);
    return parseResponse(response);
  }

  private static ContactSyncResult parseResponse(HttpResponse response) {
    Integer statusCode = response.getStatusCode();
    String body = response.getBody();

    ContactSyncResult result = String.isBlank(body)
      ? new ContactSyncResult()
      : (ContactSyncResult) JSON.deserialize(body, ContactSyncResult.class);
    result.statusCode = statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (result.success == null) {
        result.success = true;
      }
      return result;
    }

    throw new CalloutFailureException(
      String.isBlank(result.message)
        ? 'Outbound sync failed with status code ' + statusCode + '.'
        : result.message
    );
  }
}
