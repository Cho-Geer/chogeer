import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createContact from "@salesforce/apex/ShowcaseContactController.createContact";

export default class ShowcaseContactCreate extends LightningElement {
  firstName = "";
  lastName = "";
  email = "";
  title = "";
  isSaving = false;

  handleChange(event) {
    this[event.target.name] = event.target.value;
  }

  async handleSave() {
    this.isSaving = true;

    try {
      const contactId = await createContact({
        firstName: this.firstName,
        lastName: this.lastName,
        email: this.email,
        title: this.title
      });

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Contact created",
          message: `Record Id: ${contactId}`,
          variant: "success"
        })
      );
      this.dispatchEvent(
        new CustomEvent("contactcreated", {
          detail: { contactId }
        })
      );
      this.resetForm();
    } catch (error) {
      const message =
        error?.body?.message ||
        error?.message ||
        "Unable to create the contact.";
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Create failed",
          message,
          variant: "error"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }

  resetForm() {
    this.firstName = "";
    this.lastName = "";
    this.email = "";
    this.title = "";
  }
}
