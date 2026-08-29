import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";
import { MessageContext, publish } from "lightning/messageService";
import CONTACT_CREATED_CHANNEL from "@salesforce/messageChannel/ContactCreated__c";
import createContact from "@salesforce/apex/ShowcaseContactController.createContact";

export default class ShowcaseContactCreate extends LightningElement {
  @wire(MessageContext) messageContext;

  @api recordId;
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
      let contactId;
      try {
        contactId = await createContact({
          firstName: this.firstName,
          lastName: this.lastName,
          email: this.email,
          title: this.title,
          accountId: this.recordId
        });
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
        return;
      }

      this.dispatchEvent(
        new CustomEvent("contactcreated", {
          detail: { contactId }
        })
      );

      let toastMessage = `Record Id: ${contactId}`;
      try {
        publish(this.messageContext, CONTACT_CREATED_CHANNEL, {
          accountId: this.recordId,
          contactId
        });
      } catch (error) {
        toastMessage =
          "Contact created, but automatic list refresh failed. Refresh the page to see it.";
      }

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Contact created",
          message: toastMessage,
          variant: "success"
        })
      );
      this.resetForm();
      this.dispatchEvent(new CloseActionScreenEvent());
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
