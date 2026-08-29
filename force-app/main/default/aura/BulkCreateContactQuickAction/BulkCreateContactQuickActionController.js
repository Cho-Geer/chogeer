({
  handleRecordUpdated: function (component, event) {
    const changeType = event.getParam("changeType");
    if (changeType === "LOADED") {
      component.set("v.state", "ready");
    } else if (changeType === "ERROR") {
      component.set("v.state", "error");
    }
  }
});
