import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import {
  registerRefreshHandler,
  unregisterRefreshHandler
} from "lightning/refresh";
import {
  MessageContext,
  subscribe,
  unsubscribe
} from "lightning/messageService";
import CONTACT_CREATED_CHANNEL from "@salesforce/messageChannel/ContactCreated__c";
import { refreshApex } from "@salesforce/apex";
import getContactsByAccountPage from "@salesforce/apex/ShowcaseContactController.getContactsByAccountPage";

const ACCOUNT_URL_PATTERN =
  /\/lightning\/r\/Account\/([a-zA-Z0-9]{15,18})(?:\/|$)/;

const COLUMNS = [
  {
    label: "Last Name",
    fieldName: "contactUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "lastName" },
      target: "_self"
    }
  },
  { label: "First Name", fieldName: "firstName" },
  { label: "Email", fieldName: "email", type: "email" },
  { label: "Title", fieldName: "title" },
  { label: "Account", fieldName: "accountName" }
];

export default class ShowcaseContactList extends LightningElement {
  _recordId;
  accountId;
  columns = COLUMNS;
  contacts = [];
  errorMessage;
  pageNumber = 1;
  pageSize = 10;
  totalRecords = 0;
  totalPages = 0;
  refreshHandlerId;
  subscription;
  wiredContactsResult;

  @wire(MessageContext) messageContext;

  connectedCallback() {
    this.refreshHandlerId = registerRefreshHandler(
      this,
      this.handleRefresh.bind(this)
    );
    this.setAccountIdFromCurrentUrl();
  }

  renderedCallback() {
    this.subscribeToContactCreated();
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = undefined;
    }
    if (this.refreshHandlerId !== undefined) {
      unregisterRefreshHandler(this.refreshHandlerId);
      this.refreshHandlerId = undefined;
    }
  }

  async handleRefresh() {
    if (this.wiredContactsResult) {
      await refreshApex(this.wiredContactsResult);
    }
    return true;
  }

  subscribeToContactCreated() {
    if (this.subscription) {
      return;
    }

    this.subscription = subscribe(
      this.messageContext,
      CONTACT_CREATED_CHANNEL,
      (message) => this.handleContactCreated(message)
    );
  }

  handleContactCreated(message) {
    if (message?.accountId === this.accountId) {
      if (this.pageNumber !== 1) {
        this.pageNumber = 1;
        return;
      }

      this.refreshContacts().catch((error) => {
        this.errorMessage =
          error?.body?.message ||
          error?.message ||
          "Unable to refresh contacts.";
      });
    }
  }

  async refreshContacts() {
    if (this.wiredContactsResult) {
      await refreshApex(this.wiredContactsResult);
    }
  }

  handlePrevious() {
    if (this.hasPreviousPage) {
      this.pageNumber -= 1;
    }
  }

  handleNext() {
    if (this.hasNextPage) {
      this.pageNumber += 1;
    }
  }

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    this.accountId = value || this.getAccountIdFromCurrentUrl();
  }

  @wire(CurrentPageReference)
  wiredPageReference(pageReference) {
    const pageRecordId =
      pageReference?.attributes?.recordId ||
      pageReference?.state?.recordId ||
      pageReference?.state?.c__recordId;
    if (!this._recordId && pageRecordId) {
      this.accountId = pageRecordId;
    } else if (!this._recordId) {
      this.setAccountIdFromCurrentUrl();
    }
  }

  getAccountIdFromCurrentUrl() {
    if (typeof window === "undefined") {
      return undefined;
    }

    const match = window.location.pathname.match(ACCOUNT_URL_PATTERN);
    return match?.[1];
  }

  setAccountIdFromCurrentUrl() {
    if (!this._recordId) {
      const currentUrlAccountId = this.getAccountIdFromCurrentUrl();
      if (currentUrlAccountId) {
        this.accountId = currentUrlAccountId;
      }
    }
  }

  @wire(getContactsByAccountPage, {
    accountId: "$accountId",
    pageNumber: "$pageNumber",
    pageSize: "$pageSize"
  })
  wiredContacts(result) {
    this.wiredContactsResult = result;
    const { data, error } = result;

    if (data) {
      this.pageNumber = data.pageNumber;
      this.totalRecords = data.totalRecords;
      this.totalPages = data.totalPages;
      this.contacts = (data.records || []).map((contact) => ({
        ...contact,
        contactUrl: `/lightning/r/Contact/${contact.contactId}/view`
      }));
      this.errorMessage = undefined;
      return;
    }

    this.contacts = [];
    this.totalRecords = 0;
    this.totalPages = 0;
    this.errorMessage =
      error?.body?.message || error?.message || "Unable to load contacts.";
  }

  get hasContacts() {
    return this.contacts.length > 0;
  }

  get hasPreviousPage() {
    return this.pageNumber > 1;
  }

  get hasNextPage() {
    return this.pageNumber < this.totalPages;
  }

  get isPreviousDisabled() {
    return !this.hasPreviousPage;
  }

  get isNextDisabled() {
    return !this.hasNextPage;
  }

  get showPagination() {
    return this.hasContacts;
  }

  get paginationLabel() {
    return `Page ${this.pageNumber} of ${this.totalPages} (${this.totalRecords} total)`;
  }
}
