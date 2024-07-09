import { LightningElement } from "lwc";

export default class BaseElement extends LightningElement {
  onChange = () => {
    console.log("---------BaseElement onChange----------");
  };
}
