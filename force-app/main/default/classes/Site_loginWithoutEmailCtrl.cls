/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 05-16-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class Site_loginWithoutEmailCtrl {
  public String name { get; set; }
  public String password { get; set; }
  public String st { get; private set; }

  public String signin() {
    System.debug('-----------------signin-------------------');
    System.debug(this.name + ' ' + this.password);
    System.debug('------------------------------------');
    this.st = '12323456';
    return null;
  }

  public PageReference login() {
    System.debug('-----------------login---------------------');
    return Site.login(this.name, this.password, '/');
  }
}
