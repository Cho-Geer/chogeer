import { createElement } from "lwc";
import { createApexTestWireAdapter } from "@salesforce/sfdx-lwc-jest";

const mockRefreshApex = jest.fn().mockResolvedValue();
const mockRegisterRefreshHandler = jest.fn().mockReturnValue(1);
const mockUnregisterRefreshHandler = jest.fn();
const mockSubscribe = jest.fn().mockReturnValue({});
const mockUnsubscribe = jest.fn();
const mockPublish = jest.fn();

jest.mock(
  "@salesforce/apex",
  () => ({
    refreshApex: mockRefreshApex
  }),
  { virtual: true }
);

jest.mock(
  "lightning/refresh",
  () => ({
    registerRefreshHandler: mockRegisterRefreshHandler,
    unregisterRefreshHandler: mockUnregisterRefreshHandler
  }),
  { virtual: true }
);

jest.mock(
  "lightning/messageService",
  () => {
    const { createTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      MessageContext: createTestWireAdapter(jest.fn()),
      subscribe: mockSubscribe,
      unsubscribe: mockUnsubscribe,
      publish: mockPublish
    };
  },
  { virtual: true }
);

const { MessageContext } = require("lightning/messageService");

jest.mock(
  "@salesforce/messageChannel/ContactCreated__c",
  () => ({
    default: "ContactCreated__c"
  }),
  { virtual: true }
);

const mockGetRecentContactsAdapter = createApexTestWireAdapter(jest.fn());

jest.mock(
  "@salesforce/apex/ShowcaseContactController.getContactsByAccountPage",
  () => ({
    default: mockGetRecentContactsAdapter
  }),
  { virtual: true }
);

const ShowcaseContactList = require("c/showcaseContactList").default;

const mockContacts = [
  {
    contactId: "003000000000001AAA",
    firstName: "Mina",
    lastName: "Chen",
    email: "mina.chen@example.com",
    title: "Platform Engineer",
    accountName: "Customer Platform"
  }
];

const mockPage = {
  records: mockContacts,
  pageNumber: 1,
  pageSize: 10,
  totalRecords: 1,
  totalPages: 1
};

function flushPromises() {
  return Promise.resolve();
}

describe("c-showcase-contact-list", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders contacts from the Apex wire", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);

    await flushPromises();
    expect(mockGetRecentContactsAdapter.getLastConfig()).toEqual({
      accountId: "001000000000001AAA",
      pageNumber: 1,
      pageSize: 10
    });

    mockGetRecentContactsAdapter.emit(mockPage);
    await flushPromises();

    const dataTable = element.shadowRoot.querySelector("lightning-datatable");
    expect(dataTable).not.toBeNull();
    expect(dataTable.data).toEqual([
      {
        ...mockContacts[0],
        contactUrl: "/lightning/r/Contact/003000000000001AAA/view"
      }
    ]);
    expect(dataTable.columns).toHaveLength(5);
    expect(dataTable.columns[0]).toEqual({
      label: "Last Name",
      fieldName: "contactUrl",
      type: "url",
      typeAttributes: {
        label: { fieldName: "lastName" },
        target: "_self"
      }
    });
    expect(dataTable.columns[1]).toEqual({
      label: "First Name",
      fieldName: "firstName"
    });
    expect(element.shadowRoot.textContent).not.toContain(
      "No contacts available yet."
    );
  });

  it("keeps an empty First Name as plain text while linking Last Name", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);

    mockGetRecentContactsAdapter.emit({
      ...mockPage,
      records: [
        {
          ...mockContacts[0],
          firstName: null,
          lastName: "Chen"
        }
      ]
    });
    await flushPromises();

    const dataTable = element.shadowRoot.querySelector("lightning-datatable");
    expect(dataTable.columns[0].typeAttributes.label).toEqual({
      fieldName: "lastName"
    });
    expect(dataTable.columns[1]).toEqual({
      label: "First Name",
      fieldName: "firstName"
    });
    expect(dataTable.data[0].firstName).toBeNull();
    expect(dataTable.data[0].contactUrl).toBe(
      "/lightning/r/Contact/003000000000001AAA/view"
    );
  });

  it("moves between pages and displays pagination metadata", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);

    mockGetRecentContactsAdapter.emit({
      ...mockPage,
      totalRecords: 11,
      totalPages: 2
    });
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Page 1 of 2 (11 total)");
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons).toHaveLength(2);

    buttons[1].click();
    await flushPromises();

    expect(mockGetRecentContactsAdapter.getLastConfig()).toEqual({
      accountId: "001000000000001AAA",
      pageNumber: 2,
      pageSize: 10
    });
  });

  it("shows disabled pagination controls when all contacts fit on one page", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);

    mockGetRecentContactsAdapter.emit(mockPage);
    await flushPromises();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons).toHaveLength(2);
    expect(buttons[0].disabled).toBe(true);
    expect(buttons[1].disabled).toBe(true);
    expect(element.shadowRoot.textContent).toContain("Page 1 of 1 (1 total)");
  });

  it("refreshes Apex data when the view refreshes", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);
    MessageContext.emit({});
    await flushPromises();

    const registeredHandler = mockRegisterRefreshHandler.mock.calls[0][1];
    await registeredHandler();

    expect(mockRefreshApex).toHaveBeenCalledTimes(1);
    expect(mockRefreshApex).toHaveBeenCalledWith({
      data: undefined,
      error: undefined
    });

    document.body.removeChild(element);
    expect(mockUnregisterRefreshHandler).toHaveBeenCalledWith(1);
  });

  it("refreshes Apex data when a contact is created for this account", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);
    MessageContext.emit({});
    await flushPromises();

    const messageListener = mockSubscribe.mock.calls[0][2];
    messageListener({
      accountId: "001000000000001AAA",
      contactId: "003000000000010AAA"
    });
    await flushPromises();

    expect(mockRefreshApex).toHaveBeenCalledTimes(1);
    expect(mockRefreshApex).toHaveBeenCalledWith({
      data: undefined,
      error: undefined
    });

    document.body.removeChild(element);
    expect(mockUnsubscribe).toHaveBeenCalledTimes(1);
  });

  it("does not refresh when a contact is created for another account", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);
    MessageContext.emit({});
    await flushPromises();

    const messageListener = mockSubscribe.mock.calls[0][2];
    messageListener({
      accountId: "001000000000002AAA",
      contactId: "003000000000011AAA"
    });
    await flushPromises();

    expect(mockRefreshApex).not.toHaveBeenCalled();

    document.body.removeChild(element);
    expect(mockUnsubscribe).toHaveBeenCalledTimes(1);
  });

  it("renders an error message when the Apex wire fails", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);

    mockGetRecentContactsAdapter.error({
      message: "Unable to load recent contacts."
    });
    await flushPromises();

    const dataTable = element.shadowRoot.querySelector("lightning-datatable");
    expect(dataTable).toBeNull();
    expect(element.shadowRoot.textContent).toContain(
      "Unable to load recent contacts."
    );
  });
});
