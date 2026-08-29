/* eslint-disable */
({
  handleFireCompEvent: function (component, event, helper) {
    let params = event.getParam("arguments");
    let evt = component.getEvent("registerCompEvent");
    evt.setParams({
      eventKey: params.eventKey,
      eventValue: params.eventValue
    });
    evt.fire();
  },
  handleFireAppEvent: function (component, event, helper) {
    let params = event.getParam("arguments");
    let evt = $A.get("e.c:registerAppEvent");
    evt.setParams({
      it: params.it
    });
    evt.fire();
  },
  handleApexCallEvent: function (component, event, helper) {
    let params = event.getParam("arguments");
    let compName = params.compName;
    let methodParams = params.params;
    let apexMethodName = params.apexMethodName;
    let callback = params.callback;
    let action = compName.get(apexMethodName);
    action.setParams(methodParams);
    action.setCallback(this, (response) => {
      let state = response.getState();
      let returnValue = response.getReturnValue();
      if (state === "SUCCESS" && returnValue && returnValue.isSuccess) {
        callback(returnValue);
      } else {
        const responseErrors = response.getError() || [];
        const errorMessage = responseErrors
          .map((error) => {
            if (!error) {
              return "";
            }
            if (error.message) {
              return error.message;
            }
            const pageErrors = error.pageErrors || [];
            return pageErrors.length && pageErrors[0]
              ? pageErrors[0].message
              : "";
          })
          .filter(Boolean)
          .join("; ");
        component.find("notifLib").showToast({
          title: "ERROR",
          message:
            "失敗原因：" +
            ((returnValue && returnValue.message) ||
              errorMessage ||
              "サーバー処理に失敗しました。"),
          variant: "error"
        });
      }
    });
    $A.enqueueAction(action);
  }
});
