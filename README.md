# Salesforce Platform and Integration Showcase

This repository is a curated Salesforce DX portfolio project aimed at a `Senior Salesforce Platform / Integration Engineer` role.

It is intentionally designed to show a small number of representative implementations across platform, integration, UI, and Experience Cloud style authentication flows, so reviewers can understand the technical signal quickly without digging through a large archive of experiments.

This repository is intentionally curated to showcase representative Salesforce platform and integration patterns, rather than every experimental or training artifact.

## What This Repository Demonstrates

- Experience Cloud style authentication flows using Apex, Visualforce, and Aura
- Secure Apex REST design with `@RestResource`, `with sharing`, and `Security.stripInaccessible`
- Outbound integration with HTTP callouts and Named Credential based endpoint design
- Platform Event driven processing with Apex trigger tests
- Lightning Web Components backed by Apex controllers for list and create flows
- Apex unit tests covering the main showcase implementations

## Salesforce Skills Covered

- Apex controllers and service classes
- Apex unit testing
- Visualforce
- Aura Components
- Lightning Web Components
- Experience Cloud style authentication and self-registration flows
- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- HTTP callouts
- Named Credential based integration configuration
- Platform Events
- trigger-based event processing
- reviewer-friendly repository curation and architecture explanation

## Representative Implementations

### 1. Experience Cloud / Authentication Flows

Representative Apex files:

- `force-app/main/default/classes/CommunitiesLoginController.cls`
- `force-app/main/default/classes/CommunitiesSelfRegController.cls`
- `force-app/main/default/classes/ForgotPasswordController.cls`
- `force-app/main/default/classes/ChangePasswordController.cls`
- `force-app/main/default/classes/MyProfilePageController.cls`
- `force-app/main/default/classes/LightningLoginFormController.cls`
- `force-app/main/default/classes/LightningSelfRegisterController.cls`
- `force-app/main/default/classes/LightningForgotPasswordController.cls`
- `force-app/main/default/classes/SiteLoginController.cls`
- `force-app/main/default/classes/SiteRegisterController.cls`

Representative test files:

- `force-app/main/default/classes/CommunitiesLoginControllerTest.cls`
- `force-app/main/default/classes/CommunitiesSelfRegControllerTest.cls`
- `force-app/main/default/classes/ForgotPasswordControllerTest.cls`
- `force-app/main/default/classes/ChangePasswordControllerTest.cls`
- `force-app/main/default/classes/MyProfilePageControllerTest.cls`
- `force-app/main/default/classes/LightningLoginFormControllerTest.cls`
- `force-app/main/default/classes/LightningSelfRegisterControllerTest.cls`
- `force-app/main/default/classes/LightningForgotPasswordControllerTest.cls`
- `force-app/main/default/classes/SiteLoginControllerTest.cls`
- `force-app/main/default/classes/SiteRegisterControllerTest.cls`

Representative Visualforce pages:

- `force-app/main/default/pages/CommunitiesLogin.page`
- `force-app/main/default/pages/CommunitiesSelfReg.page`
- `force-app/main/default/pages/ForgotPassword.page`
- `force-app/main/default/pages/ChangePassword.page`
- `force-app/main/default/pages/MyProfilePage.page`
- `force-app/main/default/pages/SiteLogin.page`
- `force-app/main/default/pages/SiteRegister.page`

Representative Aura files:

- `force-app/main/default/aura/loginForm/loginForm.cmp`
- `force-app/main/default/aura/selfRegister/selfRegister.cmp`
- `force-app/main/default/aura/forgotPassword/forgotPassword.cmp`

These examples demonstrate:

- login and self-registration flow handling
- password reset and profile maintenance flows
- UI-to-controller coordination across Visualforce, Aura, and Apex
- Experience Cloud oriented entry points that are easy to explain in interviews

### 2. Secure REST Endpoint

Representative files:

- `force-app/main/default/classes/ShowcaseContactRestResource.cls`
- `force-app/main/default/classes/ShowcaseContactRestResourceTest.cls`

This example demonstrates:

- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- request validation and response shaping
- reviewer-friendly secure data exposure patterns

### 3. Outbound Integration / HTTP Callout

Representative files:

- `force-app/main/default/classes/ShowcaseContactSyncService.cls`
- `force-app/main/default/classes/ShowcaseContactSyncServiceTest.cls`

This example demonstrates:

- outbound HTTP callout
- Named Credential based endpoint configuration
- typed request and response wrappers
- mock-based callout testing
- integration-oriented Apex service design

### 4. Platform Event and Trigger-Based Processing

Representative files:

- `force-app/main/default/triggers/OrderEventTrigger.trigger`
- `force-app/main/default/classes/OrderEventTriggerTest.cls`
- `force-app/main/default/objects/Order_Event__e/Order_Event__e.object-meta.xml`

This example demonstrates:

- Platform Event definition
- trigger-based event processing
- event-driven follow-up automation
- testing with `EventBus.publish`

### 5. LWC + Apex Coordination

Representative files:

- `force-app/main/default/classes/ShowcaseContactController.cls`
- `force-app/main/default/classes/ShowcaseContactControllerTest.cls`
- `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`
- `force-app/main/default/lwc/showcaseContactCreate/showcaseContactCreate.js`

This example demonstrates:

- Apex-backed contact list retrieval
- Apex-backed contact creation
- client/server coordination between LWC and Apex
- a simple UI pattern that is easy to discuss in portfolio review and interviews

### 6. Additional Platform Samples Kept As Supporting Material

Representative files:

- `force-app/main/default/classes/ApexSecurityRest.cls`
- `force-app/main/default/classes/ApexSecurityRestTest.cls`
- `force-app/main/default/classes/Account_batchable.cls`
- `force-app/main/default/classes/Test_account_batchable.cls`
- `force-app/main/default/flows/New_Contact.flow-meta.xml`
- `force-app/main/default/flows/Cloud_new_process.flow-meta.xml`

These files remain useful as supporting material, but they are not the primary review path for this repository.

## Repository Structure

Primary review surface:

- `force-app/main/default/classes/`
- `force-app/main/default/pages/`
- `force-app/main/default/aura/`
- `force-app/main/default/lwc/`
- `force-app/main/default/triggers/`
- `force-app/main/default/objects/`

Supporting project files:

- `sfdx-project.json`
- `package.json`
- `jest.config.js`
- `playwright.config.js`

## Architecture Notes

This repository follows a simple portfolio principle:

- keep the review surface small
- keep the repository theme clear
- show representative platform and integration patterns
- preserve the strongest existing Experience Cloud examples
- avoid turning the repo into a dump of every historical sample

In practice, that means the core story of this repository is:

1. Experience Cloud / authentication flows already present in `chogeer`
2. a curated set of platform and integration examples added to improve breadth
3. a deliberate review order so hiring teams can understand the signal quickly

## How To Review This Repository

Suggested review order:

1. `force-app/main/default/classes/CommunitiesLoginController.cls`
2. `force-app/main/default/classes/CommunitiesSelfRegController.cls`
3. `force-app/main/default/classes/MyProfilePageController.cls`
4. `force-app/main/default/pages/CommunitiesLogin.page`
5. `force-app/main/default/aura/loginForm/loginForm.cmp`
6. `force-app/main/default/classes/ShowcaseContactRestResource.cls`
7. `force-app/main/default/classes/ShowcaseContactSyncService.cls`
8. `force-app/main/default/triggers/OrderEventTrigger.trigger`
9. `force-app/main/default/classes/ShowcaseContactController.cls`
10. `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`

## Local Development

Install dependencies:

```bash
npm install
```

Authenticate to a Salesforce org:

```bash
sf org login web --alias <your-org-alias>
```

Deploy source:

```bash
sf project deploy start --target-org <your-org-alias>
```

Run Apex tests:

```bash
sf apex run test --target-org <your-org-alias> --test-level RunLocalTests
```

Run LWC unit tests:

```bash
npm run test:unit
```

Run Playwright E2E tests:

```bash
npm run test:e2e
```

Named Credential note:

- The outbound callout example expects a Named Credential called `CustomerProfileService`.

## Notes

- This repository is positioned as a curated showcase, not a complete archive of all Salesforce experiments.
- Some additional legacy or practice-oriented files remain in the repo, but the sections above define the intended review path.
- For broader full-stack evidence outside Salesforce, the separate booking system repositories are the stronger reference point.

## Author

Zixi Tao

## Target Role

Senior Salesforce Platform / Integration Engineer
