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
    helper.loadAccounts(component, "", true);
    component.set("v.contactList", [{ sobjectType: "Contact" }]);
  },
  handleBulkCreate: function (component, event, helper) {
    const allContacts = component.get("v.contactList") || [];
    const selectedContacts = allContacts.filter(
      (contact) => contact && contact.checked === true
    );
    if (selectedContacts.length === 0) {
      component.find("notifLib").showToast({
        title: "ERROR",
        message: "作成する取引先責任者を選択してください。",
        variant: "error"
      });
      return;
    }

    const recordId = component.get("v.recordId");
    const contactList = selectedContacts
      .map((contact) =>
        recordId ? Object.assign({}, contact, { AccountId: recordId }) : contact
      );
    const apexMethod = recordId ? "c.saveContactsForAccount" : "c.saveContacts";
    const params = recordId
      ? { accountId: recordId, contactList: contactList }
      : { contactList: contactList };
    component
      .find("eventService")
      .apexCallEvent(
        component,
        params,
        apexMethod,
        (resp) => {
          component.set(
            "v.contactList",
            [
              recordId
                ? { sobjectType: "Contact", AccountId: recordId }
              : { sobjectType: "Contact" }
            ]
          );
          component.set("v.check", false);
          component.set("v.checkedIndexList", []);
          let successMessage = "成功しました！";
          if (recordId) {
            try {
              const contactCreatedChannel = component.find(
                "contactCreatedChannel"
              );
              if (contactCreatedChannel) {
                contactCreatedChannel.publish({ accountId: recordId });
              } else {
                successMessage +=
                  " 一覧の自動更新に失敗したため、ページを更新してください。";
              }
            } catch (error) {
              successMessage +=
                " 一覧の自動更新に失敗したため、ページを更新してください。";
              console.error("Contact list refresh notification failed", error);
            }
          }
          component.find("notifLib").showToast({
            title: "SUCCESS",
            message: successMessage,
            variant: "success"
          });
          if (component.get("v.isAccountContext")) {
            const closeAction = $A.get("e.force:closeQuickAction");
            if (closeAction) {
              closeAction.fire();
            }
          }
          console.log(JSON.stringify(component.get("v.contactList")));
        }
      );
  },
  handleCompEvent: function (component, event, helper) {
    helper.doCompEvent(component, event);
  },
  handleCheckAll: function (component, event, helper) {
    const checked = event.getParam("checked");
    const contactList = (component.get("v.contactList") || []).map(
      (contact) => Object.assign({}, contact, { checked: checked })
    );
    const checkedIndexList = checked
      ? contactList.map((contact, index) => index)
      : [];

    component.set("v.check", checked);
    component.set("v.checkedIndexList", checkedIndexList);
    component.set("v.contactList", contactList);
  },
  handleButtonSelect: function (component, event, helper) {
    const value = event.getParam("value");
    const contactList = component.get("v.contactList") || [];
    let checkedIndexList = component.get("v.checkedIndexList") || [];
    if (value === "AddRow") {
      component.set(
        "v.contactList",
        contactList.concat([{ sobjectType: "Contact" }])
      );
      component.set("v.check", false);
      return;
    }
    if (value === "DeleteRow") {
      if (checkedIndexList.length === 0) {
        component.find("notifLib").showToast({
          title: "INFO",
          message: "削除する行を選択してください。",
          variant: "info"
        });
        return;
      }
      const remainingContacts = contactList.slice();
      checkedIndexList
        .slice()
        .sort((a, b) => b - a)
        .forEach((element) => remainingContacts.splice(element, 1));
      checkedIndexList = [];
      component.set("v.check", false);
      component.set("v.checkedIndexList", checkedIndexList);
      component.set("v.contactList", remainingContacts);
    }
  }
});
