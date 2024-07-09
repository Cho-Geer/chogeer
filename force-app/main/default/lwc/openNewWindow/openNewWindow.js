// openNewWindow.js
import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord } from "lightning/uiRecordApi";

const FIELDS = ["Contact.Name"];

export default class OpenNewWindow extends NavigationMixin(LightningElement) {
  @api recordId;
  @wire(getRecord, { recordId: "$recordId", fields: FIELDS }) contact;

  @api invoke() {
    this[NavigationMixin.Navigate]({
      type: "standard__component",
      attributes: {
        componentName: "c__wraper_testTrack"
      },
      state: {}
    });
  }
}
