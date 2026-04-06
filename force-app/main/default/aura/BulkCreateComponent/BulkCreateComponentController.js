/* eslint-disable */
({
  doInit: function (component, event, helper) {
    const options = [];
    component
      .find("eventService")
      .apexCallEvent(component, {}, "c.getRecordType", (response) => {
        response.dataList.forEach((element) => {
          options.push({ label: element.Name, value: element.Id });
        });
        component.set("v.options", options);
      });
    component.set("v.contactList", [{ sobjectType: "Contact" }]);
  },
  handleBulkCreate: function (component, event, helper) {
    component
      .find("eventService")
      .apexCallEvent(
        component,
        { contactList: component.get("v.contactList") },
        "c.saveContacts",
        (resp) => {
          component.set("v.contactList", [{ sobjectType: "Contact" }]);
          component.find("notifLib").showToast({
            title: "SUCCESS",
            message: "成功しました！",
            variant: "success"
          });
          console.log(JSON.stringify(component.get("v.contactList")));
        }
      );
  },
  handleCompEvent: function (component, event, helper) {
    helper.doCompEvent(component, event);
  },
  handleButtonSelect: function (component, event, helper) {
    const value = event.getParam("value");
    const contactList = component.get("v.contactList");
    let checkedIndexList = component.get("v.checkedIndexList");
    switch (value) {
      case "AddRow":
        contactList.push({ sobjectType: "Contact" });
        break;
      case "DeleteRow":
        if (checkedIndexList.length > 0) {
          checkedIndexList.sort((a, b) => b - a);
          checkedIndexList.forEach((element) => {
            contactList.splice(element, 1);
          });
        }
        checkedIndexList = [];
        component.set("v.check", false);
        break;
    }
    component.set("v.checkedIndexList", checkedIndexList);
    component.set("v.contactList", contactList);
    helper.doAddContact(component, contactList.length);
  }
});
