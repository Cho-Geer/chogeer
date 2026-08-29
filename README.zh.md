# Salesforce 平台与集成展示项目

本仓库是一个精心策划的 Salesforce DX 作品集项目,面向 `Senior Salesforce Platform / Integration Engineer` 岗位。

项目刻意只展示平台、集成、UI 中少量具有代表性的实现,以便评审者无需翻阅大量实验性历史代码,即可快速理解其中蕴含的技术信号。

本仓库刻意做了精选,旨在展示具有代表性的 Salesforce 平台与集成模式,而非展示所有的实验性或练习性产物。

## 本仓库展示的内容

- 结合 `@RestResource`、`with sharing` 和 `Security.stripInaccessible` 的安全 Apex REST 设计
- 基于 HTTP Callout 和 Named Credential 的出站集成端点设计
- 由 Platform Event 驱动的处理逻辑,以及对应的 Apex Trigger 测试
- 由 Apex Controller 支撑的 Lightning Web Components 列表与创建流程
- 覆盖主要展示实现的 Apex 单元测试

## 涉及的 Salesforce 技能

- Apex Controller 与 Service 类
- Apex 单元测试
- Visualforce
- Aura Components
- Lightning Web Components
- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- HTTP Callout
- 基于 Named Credential 的集成配置
- Platform Events
- 基于 Trigger 的事件处理
- 对评审友好的仓库策划与架构说明能力

## 代表性实现

### 1. 安全的 REST 端点

代表性文件:

- `force-app/main/default/classes/ShowcaseContactRestResource.cls`
- `force-app/main/default/classes/ShowcaseContactRestResourceTest.cls`

本示例展示了:

- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- 请求校验与响应整形
- 对评审友好的安全数据暴露模式

### 2. 出站集成 / HTTP Callout

代表性文件:

- `force-app/main/default/classes/ShowcaseContactSyncService.cls`
- `force-app/main/default/classes/ShowcaseContactSyncServiceTest.cls`

本示例展示了:

- 出站 HTTP Callout
- 基于 Named Credential 的端点配置
- 类型化的请求与响应包装类
- 基于 Mock 的 Callout 测试
- 面向集成的 Apex Service 设计

### 3. Platform Event 与基于 Trigger 的处理

代表性文件:

- `force-app/main/default/triggers/OrderEventTrigger.trigger`
- `force-app/main/default/classes/OrderEventTriggerTest.cls`
- `force-app/main/default/objects/Order_Event__e/Order_Event__e.object-meta.xml`

本示例展示了:

- Platform Event 的定义
- 基于 Trigger 的事件处理
- 事件驱动的后续自动化
- 使用 `EventBus.publish` 进行测试

### 4. LWC + Apex 协作

代表性文件:

- `force-app/main/default/classes/ShowcaseContactController.cls`
- `force-app/main/default/classes/ShowcaseContactControllerTest.cls`
- `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`
- `force-app/main/default/lwc/showcaseContactCreate/showcaseContactCreate.js`

本示例展示了:

- 由 Apex 支撑的联系人列表查询
- 由 Apex 支撑的联系人创建
- LWC 与 Apex 的客户端/服务器协作
- 在作品集评审和面试中易于讨论的简洁 UI 模式

### 5. 作为辅助资料保留的其他平台示例

代表性文件:

- `force-app/main/default/classes/ApexSecurityRest.cls`
- `force-app/main/default/classes/ApexSecurityRestTest.cls`
- `force-app/main/default/classes/Account_batchable.cls`
- `force-app/main/default/classes/Test_account_batchable.cls`
- `force-app/main/default/flows/New_Contact.flow-meta.xml`
- `force-app/main/default/flows/Cloud_new_process.flow-meta.xml`

这些文件仍然是有用的辅助资料,但不是本仓库的主要评审路径。

## 仓库结构

主要评审对象:

- `force-app/main/default/classes/`
- `force-app/main/default/pages/`
- `force-app/main/default/aura/`
- `force-app/main/default/lwc/`
- `force-app/main/default/triggers/`
- `force-app/main/default/objects/`

辅助项目文件:

- `sfdx-project.json`
- `package.json`
- `jest.config.js`
- `playwright.config.js`

## 架构说明

本仓库遵循一个简单的作品集原则:

- 让评审面保持小巧
- 让仓库主题保持清晰
- 展示具有代表性的平台与集成模式
- 避免把仓库变成所有历史样本的堆放地

实际来看,本仓库的核心叙事是:

1. 一组精选加入、覆盖平台/集成/UI 广度的示例
2. 一套有意的评审顺序,让招聘方可以快速理解技术信号

## 如何评审本仓库

建议的评审顺序:

1. `force-app/main/default/classes/ShowcaseContactRestResource.cls`
2. `force-app/main/default/classes/ShowcaseContactSyncService.cls`
3. `force-app/main/default/triggers/OrderEventTrigger.trigger`
4. `force-app/main/default/classes/ShowcaseContactController.cls`
5. `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`

## 本地开发

安装依赖:

```bash
npm install
```

登录 Salesforce Org:

```bash
sf org login web --alias <your-org-alias>
```

部署源码:

```bash
sf project deploy start --target-org <your-org-alias>
```

运行 Apex 测试:

```bash
sf apex run test --target-org <your-org-alias> --test-level RunLocalTests
```

运行 LWC 单元测试:

```bash
npm run test:unit
```

运行 Playwright E2E 测试:

```bash
npm run test:e2e
```

Named Credential 相关说明:

- 出站 Callout 示例期望存在一个名为 `CustomerProfileService` 的 Named Credential。

## 备注

- 本仓库定位为"精选展示",而非 Salesforce 所有实验样本的完整归档。
- 仓库中仍保留一些遗留的或练习性质的文件,但上述各节定义了期望的评审路径。
- 在 Salesforce 之外,更广义的全栈能力的证据,可参考独立的预约系统仓库。

## 作者

Zixi Tao

## 目标岗位

Senior Salesforce Platform / Integration Engineer

---

## 🇯🇵 日本語 | 🇬🇧 English

- [日本語版](./README.md)
- [English version](./README.en.md)
