({
  doCheckRow: function (component) {
    component.find("eventService").fireCompEvent("CheckRow", {
      index: component.get("v.index"),
      checked: component.find("checkbox").get("v.checked")
    });
  },
  doAccountId: function (divCombobox) {
    $A.util.removeClass(divCombobox, "slds-is-open");
  }
});
