/* eslint-disable */
({
  doAddContact: function (component, length) {
    component
      .find("eventService")
      .fireCompEvent("BulkCreateComponentChild", length);
  },
  doCompEvent: function (component, event) {
    let eventKey = event.getParam("eventKey");
    let eventValue = event.getParam("eventValue");
    console.log("EventKey", eventKey, eventValue);
    if (eventKey === "GetCheckedIndexList") {
      let contactList = component.get("v.contactList");
      let checkedIndexList = component.get("v.checkedIndexList");
      if (contactList[eventValue].checked) {
        let index = checkedIndexList.indexOf(eventValue);
        if (index === -1) {
          checkedIndexList.push(eventValue);
        }
      } else {
        let index = checkedIndexList.indexOf(eventValue);
        if (index > -1) {
          checkedIndexList.splice(index, 1);
        }
      }
      console.log("checkedIndexList", checkedIndexList);
      component.set("v.checkedIndexList", checkedIndexList);
    }
  }
});
