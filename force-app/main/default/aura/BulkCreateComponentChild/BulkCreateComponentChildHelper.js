({
  filterRecordTypes: function (component, searchTerm) {
    const normalizedSearch = (searchTerm || "").trim().toLowerCase();
    const filteredOptions = (component.get("v.options") || []).filter(
      (option) =>
        !normalizedSearch ||
        (option.label || "").toLowerCase().includes(normalizedSearch)
    );
    component.set("v.recordTypeFilteredOptions", filteredOptions);
  },
  applySelectedRecordType: function (component) {
    const selectedId = component.get("v.contact.RecordTypeId");
    if (!selectedId) return;

    const selectedOption = (component.get("v.options") || []).find(
      (option) => option.value === selectedId
    );
    if (selectedOption) {
      component.set("v.recordTypeSearchTerm", selectedOption.label);
    }
  },
  applyDefaultAccount: function (component) {
    if (!component.get("v.accountLocked")) return;
    component.set("v.contact.AccountId", component.get("v.defaultAccountId"));
    component.set(
      "v.accountSearchTerm",
      component.get("v.defaultAccountName") || ""
    );
  },
  doCheckRow: function (component) {
    component.find("eventService").fireCompEvent("CheckRow", {
      index: component.get("v.index"),
      checked: component.find("checkbox").get("v.checked")
    });
  }
});
