/*
 * @Author: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @Date: 2024-07-09 07:37:48
 * @LastEditors: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @LastEditTime: 2024-07-09 07:51:53
 * @FilePath: /chogeer/force-app/main/default/aura/selfRegister/selfRegisterHelper.js
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
({
  qsToEventMap: {
    startURL: "e.c:setStartUrl"
  },

  qsToEventMap2: {
    expid: "e.c:setExpId"
  },

  handleSelfRegister: function (component) {
    var accountId = component.get("v.accountId");
    var regConfirmUrl = component.get("v.regConfirmUrl");
    var firstname = component.find("firstname").get("v.value");
    var lastname = component.find("lastname").get("v.value");
    var email = component.find("email").get("v.value");
    var includePassword = component.get("v.includePasswordField");
    var password = component.find("password").get("v.value");
    var confirmPassword = component.find("confirmPassword").get("v.value");
    var action = component.get("c.selfRegister");
    var extraFields = JSON.stringify(component.get("v.extraFields")); // somehow apex controllers refuse to deal with list of maps
    var startUrl = component.get("v.startUrl");

    startUrl = decodeURIComponent(startUrl);

    action.setParams({
      firstname: firstname,
      lastname: lastname,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      accountId: accountId,
      regConfirmUrl: regConfirmUrl,
      extraFields: extraFields,
      startUrl: startUrl,
      includePassword: includePassword
    });
    action.setCallback(this, function (a) {
      var rtnValue = a.getReturnValue();
      if (rtnValue !== null) {
        component.set("v.errorMessage", rtnValue);
        component.set("v.showError", true);
      }
    });
    $A.enqueueAction(action);
  },

  getExtraFields: function (component) {
    var action = component.get("c.getExtraFields");
    action.setParam(
      "extraFieldsFieldSet",
      component.get("v.extraFieldsFieldSet")
    );
    action.setCallback(this, function (a) {
      var rtnValue = a.getReturnValue();
      if (rtnValue !== null) {
        component.set("v.extraFields", rtnValue);
      }
    });
    $A.enqueueAction(action);
  },

  setBrandingCookie: function (component) {
    var expId = component.get("v.expid");
    if (expId) {
      var action = component.get("c.setExperienceId");
      action.setParams({ expId: expId });
      action.setCallback(this, function () {});
      $A.enqueueAction(action);
    }
  }
});
