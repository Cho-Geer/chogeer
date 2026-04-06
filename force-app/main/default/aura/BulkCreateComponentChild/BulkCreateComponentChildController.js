/* eslint-disable no-unused-vars */
({
  handleInit: function (component, event, helper) {},
  handleAccountId: function (component, event, helper) {
    const divCombobox = component.find("divCombobox");
    const divComboboxElement = divCombobox.getElement();
    const airaExpanded = divComboboxElement.getAttribute("aria-expanded");
    switch (airaExpanded) {
      case true:
        $A.util.addClass(divCombobox, "slds-is-open");
        break;
      default:
        helper.doAccountId(divCombobox);
        break;
    }
  },
  handleSuccess: function (component, event, helper) {},
  handleError: function (component, event, helper) {},
  handleDeleteRow: function (component, event, helper) {
    component
      .find("eventService")
      .fireCompEvent("deleteRow", { index: component.get("v.index") });
  },
  handleCheckRow: function (component, event, helper) {
    helper.doCheckRow(component);
  },
  handleCheckRowByCheck: function (component, event, helper) {
    if (event.getParam("value"))
      component.find("checkbox").set("v.checked", true);
    else component.find("checkbox").set("v.checked", false);
    helper.doCheckRow(component);
  },
  handleCombobox: function (component, event, helper) {
    const value = event.getParam("value");
    let name = "";
    const contact = component.get("v.contact");
    if (!$A.util.isUndefined(value)) {
      name = component.get("v.options").filter((element) => {
        return element.value === value;
      })[0].label;
      delete contact.Account;
    }
  },
  handleFocusCombobox: function (component, event, helper) {
    component.set(
      "v.spinnerFlag",
      $A.util.isEmpty(component.get("v.options")) ? true : false
    );
  },
  handleKeyup: function (component, event, helper) {},
  handleAccount: function (component, event, helper) {
    const accountList = component.find("accountList");
    const evtName = event.getName();
    $A.util.removeClass(accountList, evtName === "mouseup" ? "slds-hide" : "");
    $A.util.addClass(accountList, evtName === "blur" ? "slds-hide" : "");
  }
});
