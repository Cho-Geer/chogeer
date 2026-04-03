({
  handleInit: function (component, event, helper) {
    helper.restoreInlineState(component);
    helper.pinPageScroll(component);
    helper.syncHeightSize(component);
    helper.startLayoutObserver(component);
  },
  handleHeightSizeChange: function (component, event, helper) {
    helper.applyHeightSize(component);
  },
  handleDestroy: function (component, event, helper) {
    helper.unlockBodyScroll(component);
    helper.unpinPageScroll(component);
    if (component._scrollbarFadeTimer) {
      window.clearTimeout(component._scrollbarFadeTimer);
      component._scrollbarFadeTimer = null;
    }
    helper.stopLayoutObserver(component);
  },
  handleSlider: function (component, event, helper) {
    var middleSize = event.target.value;
    component.set("v.middleSizeNumber", middleSize);
    helper.doSetMiddleSize(component, middleSize);
  },
  handleMidControllerRerender: function (component, event, helper) {
    helper.doChangeMiddleSize(component);
  },
  handleWheel: function (component, event) {
    var scroller = event.currentTarget;
    if (!scroller) {
      return;
    }

    var deltaY = event.deltaY || 0;
    var middleOpen = component.get("v.middleSizeBar");
    var pathOpen = component.get("v.middlePathSizeBar");

    if (middleOpen || pathOpen) {
      var target = event.target;
      var middleEl = component.find("middleDiv")
        ? component.find("middleDiv").getElement()
        : null;
      var pathEl = component.find("pathDiv")
        ? component.find("pathDiv").getElement()
        : null;
      var activeEl = null;

      if (middleOpen && middleEl && middleEl.contains(target)) {
        activeEl = middleEl;
      }
      if (pathOpen && pathEl && pathEl.contains(target)) {
        activeEl = pathEl;
      }
      if (!activeEl) {
        activeEl =
          component._lastOpenedOverlay === "middleSlider" ? middleEl : pathEl;
      }

      if (activeEl) {
        var atTopOverlay = activeEl.scrollTop <= 0;
        var atBottomOverlay =
          activeEl.scrollTop + activeEl.clientHeight >=
          activeEl.scrollHeight - 1;
        if ((deltaY < 0 && atTopOverlay) || (deltaY > 0 && atBottomOverlay)) {
          event.preventDefault();
          event.stopPropagation();
        }
      }
    }
  },
  handleSizeLabel: function (component, event, helper) {
    helper.doSetSizeLabel(component, event.currentTarget.dataset.id);
  }
});
