import { LightningElement, wire } from "lwc";
import getRecentContacts from "@salesforce/apex/ShowcaseContactController.getRecentContacts";

const COLUMNS = [
  { label: "First Name", fieldName: "firstName" },
  { label: "Last Name", fieldName: "lastName" },
  { label: "Email", fieldName: "email", type: "email" },
  { label: "Title", fieldName: "title" },
  { label: "Account", fieldName: "accountName" }
];

export default class ShowcaseContactList extends LightningElement {
  columns = COLUMNS;
  contacts = [];
  errorMessage;

  @wire(getRecentContacts)
  wiredContacts({ data, error }) {
    if (data) {
      this.contacts = data;
      this.errorMessage = undefined;
      return;
    }

    this.contacts = [];
    this.errorMessage =
      error?.body?.message || error?.message || "Unable to load contacts.";
  }

  get hasContacts() {
    return this.contacts.length > 0;
  }
}
