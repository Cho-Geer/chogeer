({
  initialize: function (component, event, helper) {
    $A.get("e.siteforce:registerQueryEventMap")
      .setParams({ qsToEvent: helper.qsToEventMap })
      .fire();
    $A.get("e.siteforce:registerQueryEventMap")
      .setParams({ qsToEvent: helper.qsToEventMap2 })
      .fire();
    component.set("v.extraFields", helper.getExtraFields(component, event));
  },

  handleSelfRegister: function (component, helper) {
    helper.handleSelfRegister(component);
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
    helper.setBrandingCookie(component, event);
  },

  onKeyUp: function (component, event, helper) {
    //checks for "enter" key
    if (event.getParam("keyCode") === 13) {
      helper.handleSelfRegister(component);
    }
  }
});
