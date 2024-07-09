/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 05-14-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class LoginTestCtrl {
  public String firstName { get; set; }
  public String lastName { get; set; }
  public String email { get; set; }

  @RemoteAction
  public static ObjectForPage registerUser(
    String firstName,
    String lastName,
    String email
  ) {
    ObjectForPage op = new ObjectForPage();
    try {
      op.firstName = firstName;
      op.lastName = lastName;
      op.email = email;
      System.debug(op);
    } catch (Exception e) {
      System.debug(e.getMessage());
    }
    return op;
  }

  class ObjectForPage {
    String firstName = '';
    String lastName = '';
    String email = '';
  }
}
