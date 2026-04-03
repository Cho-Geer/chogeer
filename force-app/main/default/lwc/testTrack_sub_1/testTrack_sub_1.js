/*
 * @Author: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @Date: 2024-04-01 05:05:39
 * @LastEditors: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @LastEditTime: 2024-04-01 06:56:43
 * @FilePath: /chogeer/zhaoge.tzx/force-app/main/default/lwc/testTrack_sub_1/testTrack_sub_1.js
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
import { api } from "lwc";
import { BaseElement } from "c/baseElement";

const columns = [
  { label: "Name", fieldName: "name", type: "text" },
  { label: "Description", fieldName: "description", type: "text" }
];
export default class TestTrack_sub_1 extends BaseElement {
  @api
  planData = [];

  columns = columns;
  connectedCallback() {
    console.log(this.planData);
  }

  renderedCallback() {
    console.log(this.planData);
  }

  getParsedObject(data) {
    return JSON.parse(JSON.stringify(data));
  }
}
