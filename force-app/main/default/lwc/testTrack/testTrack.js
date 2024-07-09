/*
 * @Author: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @Date: 2024-04-01 03:00:39
 * @LastEditors: Cho-Geer 165348533+Cho-Geer@users.noreply.github.com
 * @LastEditTime: 2024-04-01 06:53:33
 * @FilePath: /chogeer/zhaoge.tzx/force-app/main/default/lwc/testTrack/testTrack.js
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
import { track } from "lwc";
import { BaseElement } from "c/baseElement";

export default class TestTrack extends BaseElement {
  @track elementFlag;
  @track planData = [];

  connectedCallback() {
    this.elementFlag = "1111111";
    this.planData = [
      {
        id: 0,
        name: "AAA",
        description: "AAAAAAAAAAAAAAAAAAAAAAAA"
      },
      {
        id: 1,
        name: "BBB",
        description: "BBBBBBBBBBBBBBBBBBBBBBBB"
      }
    ];
    console.log(this.planData);
  }

  renderedCallback() {
    console.log(this.planData);
  }

  getParsedObject(data) {
    return JSON.parse(JSON.stringify(data));
  }
}
