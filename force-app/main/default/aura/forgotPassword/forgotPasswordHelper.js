/* eslint-disable no-console */
/*
 * @Author: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @Date: 2024-07-09 07:37:48
 * @LastEditors: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @LastEditTime: 2024-07-09 07:38:38
 * @FilePath: /chogeer/force-app/main/default/aura/forgotPassword/forgotPasswordHelper.js
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
({
  qsToEventMap: {
    expid: "e.c:setExpId"
  },

  handleForgotPassword: function (component) {
    var username = component.find("username").get("v.value");
    var checkEmailUrl = component.get("v.checkEmailUrl");
    var action = component.get("c.forgotPassword");
    action.setParams({ username: username, checkEmailUrl: checkEmailUrl });
    action.setCallback(this, function (a) {
      var rtnValue = a.getReturnValue();
      if (rtnValue != null) {
        component.set("v.errorMessage", rtnValue);
        component.set("v.showError", true);
      }
    });
    $A.enqueueAction(action);
  },

  setBrandingCookie: function (component) {
    var expId = component.get("v.expid");
    if (expId) {
      var action = component.get("c.setExperienceId");
      action.setParams({ expId: expId });
      action.setCallback(this, function (result) {
        console.log(result);
      });
      $A.enqueueAction(action);
    }
  }
});
