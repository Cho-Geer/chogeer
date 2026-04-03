# Salesforce Platform and Integration Showcase

This repository is a curated Salesforce DX project for a Senior Salesforce Platform / Integration Engineer portfolio.

It combines Experience Cloud style authentication flows with a small set of representative platform and integration examples so reviewers can understand both breadth and implementation style without reading a noisy repository.

This repository is intentionally curated to showcase representative Salesforce platform and integration patterns, rather than every experimental or training artifact.

## What This Repository Demonstrates

Current repository focus:

- Apex controllers for Experience Cloud style login, self-registration, password reset, and profile flows
- Visualforce pages used as entry points for authentication and profile experiences
- Aura components that support login, self-registration, and password recovery UX
- a security-aware Apex REST endpoint
- an outbound HTTP callout service that is designed around Named Credential configuration
- a Platform Event plus trigger-based automation example
- Lightning Web Components backed by Apex for list and create flows
- Apex test classes for the main authentication-related controllers

## Salesforce Skills Covered

### Current skills shown directly in this repository

- Apex controllers
- Apex unit tests
- Visualforce
- Aura Components
- Lightning Web Components
- Experience Cloud style authentication flows
- profile-related controller logic
- `with sharing` usage in controller design

### Additional platform and integration skills shown directly in this repository

- `@RestResource`
- `Security.stripInaccessible`
- outbound HTTP callouts with Named Credential based configuration
- Platform Events
- trigger-based event processing
- integration-oriented Apex service structure
- LWC plus Apex data interaction

## Representative Implementations

### 1. Experience Cloud / Authentication Flows

Representative Apex files:

- `force-app/main/default/classes/CommunitiesLoginController.cls`
- `force-app/main/default/classes/CommunitiesSelfRegController.cls`
- `force-app/main/default/classes/ForgotPasswordController.cls`
- `force-app/main/default/classes/MyProfilePageController.cls`
- `force-app/main/default/classes/LightningLoginFormController.cls`
- `force-app/main/default/classes/LightningSelfRegisterController.cls`
- `force-app/main/default/classes/LightningForgotPasswordController.cls`

Representative test files:

- `force-app/main/default/classes/CommunitiesLoginControllerTest.cls`
- `force-app/main/default/classes/CommunitiesSelfRegControllerTest.cls`
- `force-app/main/default/classes/ForgotPasswordControllerTest.cls`
- `force-app/main/default/classes/MyProfilePageControllerTest.cls`
- `force-app/main/default/classes/LightningLoginFormControllerTest.cls`
- `force-app/main/default/classes/LightningSelfRegisterControllerTest.cls`
- `force-app/main/default/classes/LightningForgotPasswordControllerTest.cls`

Representative Visualforce pages:

- `force-app/main/default/pages/CommunitiesLogin.page`
- `force-app/main/default/pages/CommunitiesSelfReg.page`
- `force-app/main/default/pages/ForgotPassword.page`
- `force-app/main/default/pages/MyProfilePage.page`
- `force-app/main/default/pages/ChangePassword.page`

Representative Aura files:

- `force-app/main/default/aura/loginForm/loginFormController.js`
- `force-app/main/default/aura/selfRegister/selfRegisterController.js`
- `force-app/main/default/aura/forgotPassword/forgotPasswordController.js`

These examples demonstrate:

- Experience Cloud style authentication handling
- login and self-registration flow control
- password reset handling
- profile maintenance logic
- UI-to-controller coordination across Visualforce, Aura, and Apex

### 2. Supporting UI Patterns

Representative LWC files:

- `force-app/main/default/lwc/baseElement/baseElement.js`
- `force-app/main/default/lwc/tabSet/tabSet.js`
- `force-app/main/default/lwc/testTrack/testTrack.js`
- `force-app/main/default/lwc/openNewWindow/openNewWindow.js`

These examples demonstrate:

- basic LWC component structure
- component state handling
- small reusable UI patterns

### 3. Secure REST Endpoint

Representative files:

- `force-app/main/default/classes/ShowcaseContactRestResource.cls`
- `force-app/main/default/classes/ShowcaseContactRestResourceTest.cls`

This example demonstrates:

- `@RestResource`
- `with sharing`
- field-level security handling with `Security.stripInaccessible`
- deliberate response shaping for reviewer-friendly API output

### 4. Outbound Integration / HTTP Callout

Representative files:

- `force-app/main/default/classes/ShowcaseContactSyncService.cls`
- `force-app/main/default/classes/ShowcaseContactSyncServiceTest.cls`

This example demonstrates:

- outbound HTTP callout
- Named Credential based endpoint configuration
- typed request and response wrappers
- mock-based callout testing

### 5. Platform Event and Trigger-Based Processing

Representative files:

- `force-app/main/default/triggers/OrderEventTrigger.trigger`
- `force-app/main/default/classes/OrderEventTriggerTest.cls`
- `force-app/main/default/objects/Order_Event__e/Order_Event__e.object-meta.xml`

This example demonstrates:

- Platform Event definition
- trigger-based event processing
- event-driven follow-up task creation
- platform event testing with `EventBus.publish`

### 6. LWC + Apex Coordination

Representative files:

- `force-app/main/default/classes/ShowcaseContactController.cls`
- `force-app/main/default/classes/ShowcaseContactControllerTest.cls`
- `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`
- `force-app/main/default/lwc/showcaseContactCreate/showcaseContactCreate.js`

This example demonstrates:

- Apex-backed contact list retrieval
- Apex-backed contact creation
- Lightning Web Components for list and create flows
- client/server coordination that is easier to explain in interviews

## Repository Structure

`force-app/main/default`

- `classes/` Apex classes and Apex tests
- `pages/` Visualforce pages
- `aura/` Aura components
- `lwc/` Lightning Web Components
- `triggers/` Apex triggers
- `objects/` custom metadata objects including the Platform Event example
- `components/` classic Visualforce components
- `staticresources/` static assets

## Architecture Notes

This repository is being shaped around a simple portfolio principle:

- keep the repository small enough to review quickly
- keep the domain focus clear
- show representative Salesforce platform patterns instead of every historical sample
- use a few strong examples to demonstrate both platform depth and integration readiness

For that reason, this repository keeps the Experience Cloud / authentication slice that already exists here, and adds only a few carefully selected platform and integration examples from a larger source repository.

## How To Review This Repository

A practical review order is:

1. Review the authentication controllers and their tests
2. Review the related Visualforce entry pages
3. Review the Aura login / self-registration / forgot-password components
4. Review the small LWC examples
5. Review the secure REST endpoint
6. Review the outbound callout service
7. Review the Platform Event example
8. Review the Apex-backed LWC examples

## Local Development

Authenticate to a Salesforce org:

```bash
sf org login web
```

Deploy source:

```bash
sf project deploy start
```

Run Apex tests:

```bash
sf apex run test
```

Run LWC tests:

```bash
npm test
```

Named Credential note:

- The outbound callout example expects a Named Credential called `CustomerProfileService`.

## Notes

This repository is positioned as a curated Salesforce showcase rather than a complete archive of all historical Salesforce work.

For broader full-stack system evidence, see the separate booking system repositories. For Salesforce platform and integration evidence, this repository is intended to become the focused, reviewer-friendly entry point.

## Author

Zixi Tao

## Target Role

Senior Salesforce Platform / Integration Engineer
