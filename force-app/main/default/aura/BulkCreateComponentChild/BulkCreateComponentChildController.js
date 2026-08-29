/* eslint-disable no-unused-vars */
({
  handleInit: function (component, event, helper) {
    helper.filterRecordTypes(component, "");
    helper.applyDefaultAccount(component);
    helper.applySelectedRecordType(component);
  },
  handleDefaultAccountChange: function (component, event, helper) {
    helper.applyDefaultAccount(component);
  },
  handleContactChange: function (component, event, helper) {
    helper.applySelectedRecordType(component);
  },
  handleCompEvent: function (component, event, helper) {},
  handleRecordTypeOptionsChange: function (component, event, helper) {
    helper.filterRecordTypes(
      component,
      component.get("v.recordTypeSearchTerm") || ""
    );
    helper.applySelectedRecordType(component);
  },
  handleAccountFocus: function (component, event, helper) {
    component.set("v.accountDropdownOpen", true);
  },
  handleAccountBlur: function (component, event, helper) {
    window.setTimeout(
      $A.getCallback(function () {
        const rowElement = component.getElement();
        const activeElement = document.activeElement;
        const accountLookup = rowElement
          ? rowElement.querySelector(".account-lookup")
          : null;
        if (accountLookup && activeElement && accountLookup.contains(activeElement)) {
          return;
        }
        component.set("v.accountDropdownOpen", false);
      }),
      0
    );
  },
  handleAccountSearch: function (component, event, helper) {
    const searchTerm = event.getSource().get("v.value") || "";
    component.set("v.contact.AccountId", null);
    component.set("v.accountSearchTerm", searchTerm);
    component.set("v.accountDropdownOpen", true);
    component
      .find("eventService")
      .fireCompEvent("AccountSearch", searchTerm);
  },
  handleAccountSelect: function (component, event, helper) {
    const source = event.getSource();
    component.set("v.contact.AccountId", source.get("v.name"));
    component.set("v.accountSearchTerm", source.get("v.label"));
    component.set("v.accountDropdownOpen", false);
  },
  handleAccountLoadMore: function (component, event, helper) {
    component
      .find("eventService")
      .fireCompEvent(
        "AccountLoadMore",
        component.get("v.accountSearchTerm") || ""
      );
  },
  handleRecordTypeFocus: function (component, event, helper) {
    helper.filterRecordTypes(
      component,
      component.get("v.recordTypeSearchTerm") || ""
    );
    component.set("v.recordTypeDropdownOpen", true);
  },
  handleRecordTypeBlur: function (component, event, helper) {
    window.setTimeout(
      $A.getCallback(function () {
        const rowElement = component.getElement();
        const activeElement = document.activeElement;
        const recordTypeLookup = rowElement
          ? rowElement.querySelector(".record-type-lookup")
          : null;
        if (
          recordTypeLookup &&
          activeElement &&
          recordTypeLookup.contains(activeElement)
        ) {
          return;
        }
        component.set("v.recordTypeDropdownOpen", false);
      }),
      0
    );
  },
  handleRecordTypeSearch: function (component, event, helper) {
    const searchTerm = event.getSource().get("v.value") || "";
    component.set("v.contact.RecordTypeId", null);
    component.set("v.recordTypeSearchTerm", searchTerm);
    helper.filterRecordTypes(component, searchTerm);
    component.set("v.recordTypeDropdownOpen", true);
  },
  handleRecordTypeSelect: function (component, event, helper) {
    const source = event.getSource();
    component.set("v.contact.RecordTypeId", source.get("v.name"));
    component.set("v.recordTypeSearchTerm", source.get("v.label"));
    component.set("v.recordTypeDropdownOpen", false);
  },
  handleCheck: function (component, event, helper) {
    helper.doCheckRow(component);
  },
  handleChange: function (component, event, helper) {
    component.set("v.contact.RecordTypeId", event.getParam("value"));
  },
  handleButtonSelect: function (component, event, helper) {
    const value = event.getParam("value");
    if (value === "DeleteRow") {
      component
        .find("eventService")
        .fireCompEvent("DeleteRow", component.get("v.index"));
      return;
    }
    component
      .find("eventService")
      .fireCompEvent("ButtonSelect", value);
  },
  handleMenuFocus: function (component, event, helper) {
    component
      .find("eventService")
      .fireCompEvent("MenuFocus", component.get("v.index"));
  },
  handleMenuBlur: function (component, event, helper) {
    window.setTimeout(
      $A.getCallback(function () {
        const rowElement = component.getElement();
        if (rowElement && rowElement.contains(document.activeElement)) {
          return;
        }
        component
          .find("eventService")
          .fireCompEvent("MenuBlur", component.get("v.index"));
      }),
      0
    );
  },
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
  }
});
