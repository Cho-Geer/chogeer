import { createElement } from "lwc";
import ShowcaseContactCreate from "c/showcaseContactCreate";
import createContact from "@salesforce/apex/ShowcaseContactController.createContact";

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

  it("creates a contact, fires events, and resets the form", async () => {
    createContact.mockResolvedValue("003000000000010AAA");

    const element = createElement("c-showcase-contact-create", {
      is: ShowcaseContactCreate
    });

    const toastHandler = jest.fn();
    const contactCreatedHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    element.addEventListener("contactcreated", contactCreatedHandler);

    document.body.appendChild(element);

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
      title: "Integration Lead"
    });
    expect(contactCreatedHandler).toHaveBeenCalledTimes(1);
    expect(contactCreatedHandler.mock.calls[0][0].detail.contactId).toBe(
      "003000000000010AAA"
    );
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
});
