({
  rerender: function (component, helper) {
    var ret = this.superRerender();
    helper.scheduleLayoutSync(component);
    return ret;
  },
  afterRender: function (component, helper) {
    this.superAfterRender();
    helper.syncHeightSize(component);

    if (!component._onWindowResize) {
      component._onWindowResize = $A.getCallback(function () {
        if (component.isValid()) {
          helper.handleWindowResize(component);
        }
      });
      window.addEventListener("resize", component._onWindowResize);
    }
  },

  unrender: function (component) {
    if (component._onWindowResize) {
      window.removeEventListener("resize", component._onWindowResize);
      component._onWindowResize = null;
    }

    this.superUnrender();
  }
});
