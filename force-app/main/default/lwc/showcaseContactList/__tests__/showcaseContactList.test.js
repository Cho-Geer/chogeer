import { createElement } from "lwc";
import { createApexTestWireAdapter } from "@salesforce/sfdx-lwc-jest";

const mockGetRecentContactsAdapter = createApexTestWireAdapter(jest.fn());

jest.mock(
  "@salesforce/apex/ShowcaseContactController.getRecentContacts",
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
    document.body.appendChild(element);

    mockGetRecentContactsAdapter.emit(mockContacts);
    await flushPromises();

    const dataTable = element.shadowRoot.querySelector("lightning-datatable");
    expect(dataTable).not.toBeNull();
    expect(dataTable.data).toEqual(mockContacts);
    expect(dataTable.columns).toHaveLength(5);
    expect(element.shadowRoot.textContent).not.toContain(
      "No contacts available yet."
    );
  });

  it("renders an error message when the Apex wire fails", async () => {
    const element = createElement("c-showcase-contact-list", {
      is: ShowcaseContactList
    });
    document.body.appendChild(element);

    mockGetRecentContactsAdapter.error({
      body: {
        message: "Unable to load recent contacts."
      }
    });
    await flushPromises();

    const dataTable = element.shadowRoot.querySelector("lightning-datatable");
    expect(dataTable).toBeNull();
    expect(element.shadowRoot.textContent).toContain(
      "Unable to load contacts."
    );
  });
});
