/* eslint-disable */
({
  handleButtonSelect: function (component, value) {
    this.updateMenuLayers(component, -1);
    const contactList = component.get("v.contactList") || [];
    let checkedIndexList = component.get("v.checkedIndexList") || [];
    switch (value) {
      case "AddRow":
        component.set(
          "v.contactList",
          contactList.concat([{ sobjectType: "Contact" }])
        );
        component.set("v.check", false);
        break;
      case "DeleteRow":
        const remainingContacts = contactList.slice();
        checkedIndexList
          .slice()
          .sort((a, b) => b - a)
          .forEach((element) => remainingContacts.splice(element, 1));
        checkedIndexList = [];
        component.set("v.check", false);
        component.set("v.checkedIndexList", checkedIndexList);
        component.set("v.contactList", remainingContacts);
        break;
    }
  },
  deleteRowByIndex: function (component, index) {
    this.updateMenuLayers(component, -1);
    const contactList = (component.get("v.contactList") || []).slice();
    if (typeof index !== "number" || index < 0 || index >= contactList.length) {
      return;
    }

    contactList.splice(index, 1);
    const checkedIndexList = (component.get("v.checkedIndexList") || [])
      .filter((checkedIndex) => checkedIndex !== index)
      .map((checkedIndex) =>
        checkedIndex > index ? checkedIndex - 1 : checkedIndex
      );
    component.set("v.checkedIndexList", checkedIndexList);
    component.set("v.check", false);
    component.set("v.contactList", contactList);
  },
  updateMenuLayers: function (component, activeIndex) {
    const rows = component.find("bulkCreateRow") || [];
    const rowList = Array.isArray(rows) ? rows : [rows];
    const normalizedIndex =
      typeof activeIndex === "number" ? activeIndex : -1;

    component.set("v.activeMenuIndex", normalizedIndex);
    rowList.forEach((row) => {
      const rowIndex = row.get("v.index");
      let menuLayer = "normal";
      if (rowIndex === normalizedIndex) {
        menuLayer = "active";
      } else if (
        normalizedIndex >= 0 &&
        Math.abs(rowIndex - normalizedIndex) === 1
      ) {
        menuLayer = "adjacent";
      }
      row.set("v.menuLayer", menuLayer);
    });
  },
  queueAccountSearch: function (component, searchTerm) {
    if (component._accountSearchTimer) {
      window.clearTimeout(component._accountSearchTimer);
    }
    component._accountSearchTimer = window.setTimeout(() => {
      this.loadAccounts(component, searchTerm, true);
    }, 300);
  },
  loadAccounts: function (component, searchTerm, reset) {
    const normalizedSearch = (searchTerm || "").trim();
    const token = (component.get("v.accountSearchToken") || 0) + 1;
    component.set("v.accountSearchToken", token);
    component.set("v.accountLoading", true);

    const params = {
      searchStr: normalizedSearch,
      lastAccountName: reset ? null : component.get("v.accountCursorName"),
      lastAccountId: reset ? null : component.get("v.accountCursorId")
    };

    component
      .find("eventService")
      .apexCallEvent(component, params, "c.getAccountForLookup", (response) => {
        // Ignore an older response when the user has already typed a new
        // search term.
        if (token !== component.get("v.accountSearchToken")) return;

        const newOptions = (response.dataList || []).map((element) => ({
          label: element.Name,
          value: element.Id
        }));
        const currentOptions = reset
          ? []
          : component.get("v.accountOptions") || [];
        const accountOptions = currentOptions.concat(newOptions);

        component.set("v.accountOptions", accountOptions);
        component.set("v.accountSearchTerm", normalizedSearch);
        component.set("v.accountHasMore", response.hasMore === true);
        component.set("v.accountLoading", false);

        if (newOptions.length > 0) {
          const lastOption = newOptions[newOptions.length - 1];
          component.set("v.accountCursorName", lastOption.label);
          component.set("v.accountCursorId", lastOption.value);
        } else if (reset) {
          component.set("v.accountCursorName", "");
          component.set("v.accountCursorId", "");
        }
      });
  },
  doCompEvent: function (component, event) {
    let eventKey = event.getParam("eventKey");
    let eventValue = event.getParam("eventValue");
    console.log("EventKey", eventKey, eventValue);
    if (eventKey === "ButtonSelect") {
      this.handleButtonSelect(component, eventValue);
    } else if (eventKey === "DeleteRow") {
      this.deleteRowByIndex(component, eventValue);
    } else if (eventKey === "CheckRow") {
      const { index, checked } = eventValue || {};
      if (typeof index !== "number") return;

      const checkedIndexList = (
        component.get("v.checkedIndexList") || []
      ).slice();
      const checkedIndex = checkedIndexList.indexOf(index);
      if (checked && checkedIndex === -1) {
        checkedIndexList.push(index);
      } else if (!checked && checkedIndex > -1) {
        checkedIndexList.splice(checkedIndex, 1);
      }
      component.set("v.checkedIndexList", checkedIndexList);
      const contactList = component.get("v.contactList") || [];
      const allRowsChecked =
        contactList.length > 0 && checkedIndexList.length === contactList.length;
      component.set("v.check", allRowsChecked);
    } else if (eventKey === "AccountSearch") {
      this.queueAccountSearch(component, eventValue);
    } else if (eventKey === "AccountLoadMore") {
      this.loadAccounts(
        component,
        eventValue || component.get("v.accountSearchTerm"),
        false
      );
    } else if (eventKey === "MenuFocus") {
      this.updateMenuLayers(component, eventValue);
    } else if (eventKey === "MenuBlur") {
      if (component.get("v.activeMenuIndex") === eventValue) {
        this.updateMenuLayers(component, -1);
      }
    }
  }
});
