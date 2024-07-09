/*
 * @Author: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @Date: 2024-07-09 07:37:48
 * @LastEditors: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @LastEditTime: 2024-07-09 07:46:29
 * @FilePath: /chogeer/force-app/main/default/aura/loginForm/loginFormController.js
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
({
  initialize: function (component, event, helper) {
    $A.get("e.siteforce:registerQueryEventMap")
      .setParams({ qsToEvent: helper.qsToEventMap })
      .fire();
    $A.get("e.siteforce:registerQueryEventMap")
      .setParams({ qsToEvent: helper.qsToEventMap2 })
      .fire();
    component.set(
      "v.isUsernamePasswordEnabled",
      helper.getIsUsernamePasswordEnabled(component, event, helper)
    );
    component.set(
      "v.isSelfRegistrationEnabled",
      helper.getIsSelfRegistrationEnabled(component, event, helper)
    );
    component.set(
      "v.communityForgotPasswordUrl",
      helper.getCommunityForgotPasswordUrl(component, event, helper)
    );
    component.set(
      "v.communitySelfRegisterUrl",
      helper.getCommunitySelfRegisterUrl(component, event, helper)
    );
  },

  handleLogin: function (component, event, helper) {
    helper.handleLogin(component, event);
  },

  setStartUrl: function (component, event) {
    var startUrl = event.getParam("startURL");
    if (startUrl) {
      component.set("v.startUrl", startUrl);
    }
  },

  setExpId: function (component, event, helper) {
    var expId = event.getParam("expid");
    if (expId) {
      component.set("v.expid", expId);
    }
    helper.setBrandingCookie(component, event, helper);
  },

  onKeyUp: function (component, event, helper) {
    //checks for "enter" key
    if (event.getParam("keyCode") === 13) {
      helper.handleLogin(component, event, helper);
    }
  },

  navigateToForgotPassword: function (cmp) {
    var forgotPwdUrl = cmp.get("v.communityForgotPasswordUrl");
    if ($A.util.isUndefinedOrNull(forgotPwdUrl)) {
      forgotPwdUrl = cmp.get("v.forgotPasswordUrl");
    }
    var startUrl = cmp.get("v.startUrl");
    if (startUrl) {
      if (forgotPwdUrl.indexOf("?") === -1) {
        forgotPwdUrl =
          forgotPwdUrl + "?startURL=" + decodeURIComponent(startUrl);
      } else {
        forgotPwdUrl =
          forgotPwdUrl + "&startURL=" + decodeURIComponent(startUrl);
      }
    }
    var attributes = { url: forgotPwdUrl };
    $A.get("e.force:navigateToURL").setParams(attributes).fire();
  },

  navigateToSelfRegister: function (cmp) {
    var selfRegUrl = cmp.get("v.communitySelfRegisterUrl");
    if (selfRegUrl == null) {
      selfRegUrl = cmp.get("v.selfRegisterUrl");
    }
    var startUrl = cmp.get("v.startUrl");
    if (startUrl) {
      if (selfRegUrl.indexOf("?") === -1) {
        selfRegUrl = selfRegUrl + "?startURL=" + decodeURIComponent(startUrl);
      } else {
        selfRegUrl = selfRegUrl + "&startURL=" + decodeURIComponent(startUrl);
      }
    }
    var attributes = { url: selfRegUrl };
    $A.get("e.force:navigateToURL").setParams(attributes).fire();
  }
});
