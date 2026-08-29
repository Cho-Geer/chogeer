import { createElement } from "lwc";
import createContact from "@salesforce/apex/ShowcaseContactController.createContact";

const mockPublish = jest.fn();

jest.mock(
  "lightning/actions",
  () => ({
    CloseActionScreenEvent: class extends CustomEvent {
      constructor() {
        super("closeactionscreen", { bubbles: true, composed: true });
      }
    }
  }),
  { virtual: true }
);

jest.mock(
  "lightning/messageService",
  () => {
    const { createTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      MessageContext: createTestWireAdapter(jest.fn()),
      publish: mockPublish
    };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/messageChannel/ContactCreated__c",
  () => ({
    default: "ContactCreated__c"
  }),
  { virtual: true }
);

const ShowcaseContactCreate = require("c/showcaseContactCreate").default;
const { MessageContext } = require("lightning/messageService");

jest.mock(
  "@salesforce/apex/ShowcaseContactController.createContact",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

function flushPromises() {
  return Promise.resolve();
}

describe("c-showcase-contact-create", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("creates a contact, fires events, and closes the action", async () => {
    createContact.mockResolvedValue("003000000000010AAA");

    const element = createElement("c-showcase-contact-create", {
      is: ShowcaseContactCreate
    });
    element.recordId = "001000000000001AAA";

    const toastHandler = jest.fn();
    const contactCreatedHandler = jest.fn();
    const closeActionHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    element.addEventListener("contactcreated", contactCreatedHandler);
    element.addEventListener("closeactionscreen", closeActionHandler);

    document.body.appendChild(element);
    MessageContext.emit({});
    await flushPromises();

    const inputs = element.shadowRoot.querySelectorAll("lightning-input");
    inputs[0].value = "Ava";
    inputs[0].dispatchEvent(new CustomEvent("change"));
    inputs[1].value = "Li";
    inputs[1].dispatchEvent(new CustomEvent("change"));
    inputs[2].value = "ava.li@example.com";
    inputs[2].dispatchEvent(new CustomEvent("change"));
    inputs[3].value = "Integration Lead";
    inputs[3].dispatchEvent(new CustomEvent("change"));

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    expect(createContact).toHaveBeenCalledWith({
      firstName: "Ava",
      lastName: "Li",
      email: "ava.li@example.com",
      title: "Integration Lead",
      accountId: "001000000000001AAA"
    });
    expect(contactCreatedHandler).toHaveBeenCalledTimes(1);
    expect(contactCreatedHandler.mock.calls[0][0].detail.contactId).toBe(
      "003000000000010AAA"
    );
    expect(mockPublish).toHaveBeenCalledTimes(1);
    expect(mockPublish.mock.calls[0][1]).toBe("ContactCreated__c");
    expect(mockPublish.mock.calls[0][2]).toEqual({
      accountId: "001000000000001AAA",
      contactId: "003000000000010AAA"
    });
    expect(closeActionHandler).toHaveBeenCalledTimes(1);
    expect(toastHandler).toHaveBeenCalledTimes(1);
    expect(toastHandler.mock.calls[0][0].detail.title).toBe("Contact created");
  });

  it("shows an error toast when the Apex call fails", async () => {
    createContact.mockRejectedValue({
      body: {
        message: "Last name is required."
      }
    });

    const element = createElement("c-showcase-contact-create", {
      is: ShowcaseContactCreate
    });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    document.body.appendChild(element);

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    expect(createContact).toHaveBeenCalled();
    expect(toastHandler).toHaveBeenCalledTimes(1);
    expect(toastHandler.mock.calls[0][0].detail.title).toBe("Create failed");
    expect(toastHandler.mock.calls[0][0].detail.message).toBe(
      "Last name is required."
    );
  });

  it("keeps the successful creation result when publishing the refresh fails", async () => {
    createContact.mockResolvedValue("003000000000010AAA");
    mockPublish.mockImplementationOnce(() => {
      throw new Error("Message service unavailable.");
    });

    const element = createElement("c-showcase-contact-create", {
      is: ShowcaseContactCreate
    });
    element.recordId = "001000000000001AAA";
    const toastHandler = jest.fn();
    const closeActionHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    element.addEventListener("closeactionscreen", closeActionHandler);

    document.body.appendChild(element);
    MessageContext.emit({});
    await flushPromises();

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    expect(toastHandler.mock.calls[0][0].detail.title).toBe("Contact created");
    expect(toastHandler.mock.calls[0][0].detail.message).toContain(
      "automatic list refresh failed"
    );
    expect(closeActionHandler).toHaveBeenCalledTimes(1);
  });
});
