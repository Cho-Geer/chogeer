({
  createContact: function (cmp, event) {
    event.preventDefault();
    var fields = event.getParam("fields");
    fields.AccountId = cmp.get("v.recordId");
    cmp.find("myForm").submit(fields);
  },
  handleSuccess: function () {
    $A.get("e.force:refreshView").fire();
  }
});
