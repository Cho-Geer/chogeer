/*
 * @Author: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @Date: 2024-07-09 07:37:48
 * @LastEditors: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @LastEditTime: 2024-07-09 07:54:15
 * @FilePath: /chogeer/force-app/main/default/lwc/tabSet/tabSet.js
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
import { LightningElement } from "lwc";

export default class TabSet extends LightningElement {
  showTabTwo;

  connectedCallback() {
    this.showTabTwo = true;
    console.log("setTimeout");
  }
}
