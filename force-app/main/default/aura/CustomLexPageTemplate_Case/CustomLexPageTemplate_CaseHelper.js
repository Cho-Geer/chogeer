({
  normalizeHeightSize: function (heightSize) {
    if (heightSize === null || heightSize === undefined || heightSize === "") {
      return "";
    }

    if (typeof heightSize === "number") {
      return heightSize + "px";
    }

    var normalized = String(heightSize).trim();
    return /^\d+$/.test(normalized) ? normalized + "px" : normalized;
  },
  applyHeightSize: function (component) {
    var targetElement = this.getScrollerElement(component);
    if (!targetElement) {
      return;
    }

    var normalizedHeight = this.normalizeHeightSize(
      component.get("v.heightSize")
    );
    targetElement.style.height = normalizedHeight
      ? "calc(" + normalizedHeight + " - 2rem)"
      : "";
    targetElement.style.maxHeight = normalizedHeight
      ? "calc(" + normalizedHeight + " - 2rem)"
      : "";
    this.syncOpenOverlaysPosition(component);
  },
  getRootElement: function (component) {
    return component.find("customLexRoot")
      ? component.find("customLexRoot").getElement()
      : null;
  },
  applyHeaderLayout: function (component, layout) {
    var rootElement = this.getRootElement(component);
    var headerElement = this.getHeaderElement(component);
    if (!rootElement || !headerElement || !layout) {
      return;
    }

    rootElement.style.setProperty("--customLexHeaderTop", layout.top + "px");
    rootElement.style.setProperty(
      "--customLexHeaderHeight",
      layout.height + "px"
    );
    rootElement.classList.add("customLexRootPinned");
    headerElement.classList.add("customLexHeaderPinned");
  },
  syncHeaderLayout: function (component) {
    var rootElement = this.getRootElement(component);
    var headerElement = this.getHeaderElement(component);
    var targetElement = this.getScrollerElement(component);
    if (!rootElement || !headerElement || !targetElement) {
      return;
    }

    if (
      (component.get("v.middleSizeBar") ||
        component.get("v.middlePathSizeBar")) &&
      component._headerLayout
    ) {
      this.applyHeaderLayout(component, component._headerLayout);
      return;
    }

    var headerHeight = Math.max(
      0,
      Math.ceil(
        headerElement.offsetHeight ||
          headerElement.getBoundingClientRect().height ||
          0
      )
    );
    var targetTop = targetElement.getBoundingClientRect().top;
    var headerTop = Math.max(0, Math.floor(targetTop - headerHeight));
    component._headerLayout = {
      top: headerTop,
      height: headerHeight
    };
    this.applyHeaderLayout(component, component._headerLayout);
  },
  calculateAvailableScrollHeight: function (component) {
    var targetElement = this.getScrollerElement(component);
    if (!targetElement) {
      return null;
    }

    var rect = targetElement.getBoundingClientRect();
    var viewportHeight =
      window.innerHeight || document.documentElement.clientHeight || 0;
    var bottomGap = 16;
    var availableHeight = Math.max(
      160,
      Math.floor(viewportHeight - rect.top - bottomGap)
    );
    return availableHeight + "px";
  },
  syncHeightSize: function (component) {
    if (
      (component.get("v.middleSizeBar") ||
        component.get("v.middlePathSizeBar")) &&
      component._lockedScrollHeight
    ) {
      if (component.get("v.heightSize") !== component._lockedScrollHeight) {
        component.set("v.heightSize", component._lockedScrollHeight);
      } else {
        this.applyHeightSize(component);
      }
      return;
    }

    var nextHeight = this.calculateAvailableScrollHeight(component);
    if (!nextHeight) {
      return;
    }

    if (component.get("v.heightSize") !== nextHeight) {
      component.set("v.heightSize", nextHeight);
    } else {
      this.applyHeightSize(component);
    }
  },
  scheduleLayoutSync: function (component) {
    var helper = this;

    if (component._layoutSyncTimer) {
      window.clearTimeout(component._layoutSyncTimer);
    }

    component._layoutSyncTimer = window.setTimeout(
      $A.getCallback(function () {
        component._layoutSyncTimer = null;
        if (!component.isValid()) {
          return;
        }

        helper.syncHeaderLayout(component);
        helper.syncHeightSize(component);
        helper.syncOpenOverlaysPosition(component);

        if (component._layoutFollowupTimer) {
          window.clearTimeout(component._layoutFollowupTimer);
        }

        component._layoutFollowupTimer = window.setTimeout(
          $A.getCallback(function () {
            component._layoutFollowupTimer = null;
            if (!component.isValid()) {
              return;
            }

            helper.syncHeaderLayout(component);
            helper.syncHeightSize(component);
            helper.syncOpenOverlaysPosition(component);
          }),
          120
        );
      }),
      0
    );
  },
  captureOverlayBaseline: function (component) {
    var scrollElement = this.getScrollerElement(component);
    var headerElement = this.getHeaderElement(component);
    if (!scrollElement) {
      return;
    }

    var scrollRect = scrollElement.getBoundingClientRect();
    var headerRect = headerElement
      ? headerElement.getBoundingClientRect()
      : null;
    var viewportHeight =
      window.innerHeight || document.documentElement.clientHeight || 0;
    var viewportWidth =
      window.innerWidth || document.documentElement.clientWidth || 0;
    var leftOffset = Math.max(16, Math.floor(scrollRect.left));
    var rightOffset = Math.max(
      16,
      Math.floor(viewportWidth - scrollRect.right)
    );

    component._overlayBounds = {
      top: Math.max(
        0,
        Math.floor(headerRect ? headerRect.bottom : scrollRect.top)
      ),
      left: leftOffset,
      right: rightOffset,
      bottom: Math.max(16, Math.floor(viewportHeight - scrollRect.bottom))
    };

    component._lockedScrollHeight =
      this.calculateAvailableScrollHeight(component);
  },
  clearOverlayBaseline: function (component) {
    component._overlayBounds = null;
    component._lockedScrollHeight = null;
  },
  cacheDocumentOverflow: function (component) {
    if (component._overflowCacheReady) {
      return;
    }
    var docEl = document.documentElement;
    var body = document.body;
    component._overflowCacheReady = true;
    component._prevDocOverflow = docEl ? docEl.style.overflow : null;
    component._prevDocOverflowY = docEl ? docEl.style.overflowY : null;
    component._prevBodyOverflow = body ? body.style.overflow : null;
    component._prevBodyOverflowY = body ? body.style.overflowY : null;
    component._prevBodyPosition = body ? body.style.position : null;
    component._prevBodyTop = body ? body.style.top : null;
    component._prevBodyWidth = body ? body.style.width : null;
  },
  applyDocumentScrollState: function (component) {
    var docEl = document.documentElement;
    var body = document.body;
    var shouldHideOverflow = !!(
      component._pageScrollPinned || component._bodyScrollLocked
    );
    var shouldFixBody = !!component._bodyScrollLocked;

    if (docEl) {
      docEl.style.overflow = shouldHideOverflow
        ? "hidden"
        : component._prevDocOverflow || "";
      docEl.style.overflowY = shouldHideOverflow
        ? "hidden"
        : component._prevDocOverflowY || "";
    }
    if (body) {
      body.style.overflow = shouldHideOverflow
        ? "hidden"
        : component._prevBodyOverflow || "";
      body.style.overflowY = shouldHideOverflow
        ? "hidden"
        : component._prevBodyOverflowY || "";
      if (shouldFixBody) {
        if (
          component._lockedScrollTop === undefined ||
          component._lockedScrollTop === null
        ) {
          component._lockedScrollTop =
            window.pageYOffset ||
            document.documentElement.scrollTop ||
            document.body.scrollTop ||
            0;
        }
        body.style.position = "fixed";
        body.style.top = -component._lockedScrollTop + "px";
        body.style.width = "100%";
      } else {
        body.style.position = component._prevBodyPosition || "";
        body.style.top = component._prevBodyTop || "";
        body.style.width = component._prevBodyWidth || "";
        if (
          component._lockedScrollTop !== undefined &&
          component._lockedScrollTop !== null
        ) {
          window.scrollTo(0, component._lockedScrollTop);
        }
        component._lockedScrollTop = null;
      }
    }
  },
  pinPageScroll: function (component) {
    this.cacheDocumentOverflow(component);
    component._pageScrollPinned = true;
    this.applyDocumentScrollState(component);
  },
  unpinPageScroll: function (component) {
    component._pageScrollPinned = false;
    this.applyDocumentScrollState(component);
  },
  getScrollerElement: function (component) {
    return component.find("scrollTarget")
      ? component.find("scrollTarget").getElement()
      : null;
  },
  getHeaderElement: function (component) {
    return component.find("customLexHeader")
      ? component.find("customLexHeader").getElement()
      : null;
  },
  getSectionElement: function (component, dataId) {
    var sectionCmp =
      dataId === "middlePathSlider"
        ? component.find("pathDiv")
        : component.find("middleDiv");
    return sectionCmp ? sectionCmp.getElement() : null;
  },
  removeScaleClasses: function (element) {
    if (!element) {
      return;
    }
    element.classList.remove(
      "middle_scale_1",
      "middle_scale_4",
      "middle_scale_6",
      "middle_scale_8",
      "middle_scale_10"
    );
  },
  syncSectionContainer: function (element, isOpen) {
    var container = element ? element.parentElement : null;
    if (!container) {
      return;
    }

    if (isOpen) {
      container.style.height = "0";
      container.style.minHeight = "0";
      container.style.padding = "0";
      container.style.margin = "0";
      container.style.overflow = "visible";
    } else {
      container.style.height = "";
      container.style.minHeight = "";
      container.style.padding = "";
      container.style.margin = "";
      container.style.overflow = "";
    }
  },
  clearOverlayPosition: function (element) {
    if (!element) {
      return;
    }

    element.style.top = "";
    element.style.left = "";
    element.style.right = "";
    element.style.bottom = "";
  },
  syncOverlayPosition: function (component, element) {
    var scrollElement = this.getScrollerElement(component);
    if (
      !scrollElement ||
      !element ||
      !element.classList.contains("middle_fixed")
    ) {
      return;
    }

    if (!component._overlayBounds) {
      this.captureOverlayBaseline(component);
    }

    if (!component._overlayBounds) {
      return;
    }

    element.style.top = component._overlayBounds.top + "px";
    element.style.left = component._overlayBounds.left + "px";
    element.style.right = component._overlayBounds.right + "px";
    element.style.bottom = component._overlayBounds.bottom + "px";
  },
  syncOpenOverlaysPosition: function (component) {
    var middleElement = this.getSectionElement(component, "middleSlider");
    var pathElement = this.getSectionElement(component, "middlePathSlider");

    this.syncOverlayPosition(component, middleElement);
    this.syncOverlayPosition(component, pathElement);
  },
  startLayoutObserver: function (component) {
    var targetElement = this.getScrollerElement(component);
    if (!targetElement || component._layoutObserver) {
      return;
    }

    component._layoutObserver = new MutationObserver(
      $A.getCallback(
        function () {
          if (!component.isValid()) {
            return;
          }

          if (
            !component.get("v.middleSizeBar") &&
            !component.get("v.middlePathSizeBar")
          ) {
            return;
          }

          this.scheduleLayoutSync(component);
        }.bind(this)
      )
    );

    component._layoutObserver.observe(targetElement, {
      childList: true,
      subtree: true,
      attributes: true
    });
  },
  stopLayoutObserver: function (component) {
    if (component._layoutObserver) {
      component._layoutObserver.disconnect();
      component._layoutObserver = null;
    }

    if (component._layoutSyncTimer) {
      window.clearTimeout(component._layoutSyncTimer);
      component._layoutSyncTimer = null;
    }

    if (component._layoutFollowupTimer) {
      window.clearTimeout(component._layoutFollowupTimer);
      component._layoutFollowupTimer = null;
    }
  },
  updateSectionLayout: function (component, dataId, isOpen) {
    var element = this.getSectionElement(component, dataId);
    if (!element) {
      return;
    }

    this.removeScaleClasses(element);
    if (isOpen) {
      this.syncSectionContainer(element, true);
      element.classList.add("middle_fixed", "tabBar", "middle_scale_10");
      element.classList.remove("middle");
      this.syncOverlayPosition(component, element);
    } else {
      this.syncSectionContainer(element, false);
      element.classList.add("middle", "middle_scale_1");
      element.classList.remove("middle_fixed", "tabBar");
      this.clearOverlayPosition(element);
    }
  },
  restoreInlineState: function (component) {
    component.set("v.middleSizeBar", false);
    component.set("v.middlePathSizeBar", false);
    component.set("v.isMiddleLabelOpen", "表　示");
    component.set("v.isMiddlePathLabelOpen", "表　示");
    this.clearOverlayBaseline(component);
    this.updateSectionLayout(component, "middleSlider", false);
    this.updateSectionLayout(component, "middlePathSlider", false);
    this.unlockBodyScroll(component);
    this.syncHeaderLayout(component);
    this.applyHeightSize(component);
  },
  doChangeMiddleSize: function (component) {
    this.updateSectionLayout(
      component,
      "middleSlider",
      component.get("v.middleSizeBar")
    );
    this.updateSectionLayout(
      component,
      "middlePathSlider",
      component.get("v.middlePathSizeBar")
    );
  },
  doSetMiddleSize: function (component, middleSizeNumber) {
    switch (middleSizeNumber) {
      case "7":
        component.set("v.middleSize", "x-small");
        break;
      case "8":
        component.set("v.middleSize", "small");
        break;
      case "9":
        component.set("v.middleSize", "medium");
        break;
      case "10":
        component.set("v.middleSize", "large");
        break;
      case "6":
        component.set("v.middleSize", "close");
        break;
      default:
        break;
    }
  },
  lockBodyScroll: function (component) {
    this.cacheDocumentOverflow(component);
    if (component._bodyScrollLocked) {
      this.applyDocumentScrollState(component);
      return;
    }
    component._bodyScrollLocked = true;
    this.applyDocumentScrollState(component);
  },
  unlockBodyScroll: function (component) {
    if (!component._bodyScrollLocked) {
      return;
    }
    component._bodyScrollLocked = false;
    this.applyDocumentScrollState(component);
  },
  doSetMiddleOpenOrClose: function (component, sizeBar, dataId) {
    if (dataId === "middlePathSlider") {
      component.set("v.isMiddlePathLabelOpen", sizeBar ? "非表示" : "表　示");
    } else {
      component.set("v.isMiddleLabelOpen", sizeBar ? "非表示" : "表　示");
    }
  },
  closeOtherOverlay: function (component, dataId) {
    var otherDataId =
      dataId === "middlePathSlider" ? "middleSlider" : "middlePathSlider";
    var otherAttributeName =
      otherDataId === "middlePathSlider"
        ? "v.middlePathSizeBar"
        : "v.middleSizeBar";

    if (!component.get(otherAttributeName)) {
      return;
    }

    component.set(otherAttributeName, false);
    this.doSetMiddleOpenOrClose(component, false, otherDataId);
    this.updateSectionLayout(component, otherDataId, false);
  },
  doSetSizeLabel: function (component, dataId) {
    var isPathSlider = dataId === "middlePathSlider";
    var attributeName = isPathSlider
      ? "v.middlePathSizeBar"
      : "v.middleSizeBar";
    var nextValue = !component.get(attributeName);

    if (nextValue) {
      this.closeOtherOverlay(component, dataId);
      this.captureOverlayBaseline(component);
    }

    component.set(attributeName, nextValue);
    this.doSetMiddleOpenOrClose(component, nextValue, dataId);
    this.updateSectionLayout(component, dataId, nextValue);

    if (nextValue) {
      component._lastOpenedOverlay = dataId;
    }

    if (
      component.get("v.middleSizeBar") ||
      component.get("v.middlePathSizeBar")
    ) {
      this.lockBodyScroll(component);
    } else {
      this.clearOverlayBaseline(component);
      this.unlockBodyScroll(component);
    }
  },
  handleWindowResize: function (component) {
    if (
      component.get("v.middleSizeBar") ||
      component.get("v.middlePathSizeBar")
    ) {
      this.captureOverlayBaseline(component);
    }
    this.scheduleLayoutSync(component);
  }
});
