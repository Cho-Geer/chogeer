# Salesforce Platform and Integration Showcase

This repository is a curated Salesforce DX portfolio project aimed at a `Senior Salesforce Platform / Integration Engineer` role.

It is intentionally designed to show a small number of representative implementations across platform, integration, and UI, so reviewers can understand the technical signal quickly without digging through a large archive of experiments.

This repository is intentionally curated to showcase representative Salesforce platform and integration patterns, rather than every experimental or training artifact.

## What This Repository Demonstrates

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
- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- HTTP callouts
- Named Credential based integration configuration
- Platform Events
- trigger-based event processing
- reviewer-friendly repository curation and architecture explanation

## Representative Implementations

### 1. Secure REST Endpoint

Representative files:

- `force-app/main/default/classes/ShowcaseContactRestResource.cls`
- `force-app/main/default/classes/ShowcaseContactRestResourceTest.cls`

This example demonstrates:

- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- request validation and response shaping
- reviewer-friendly secure data exposure patterns

### 2. Outbound Integration / HTTP Callout

Representative files:

- `force-app/main/default/classes/ShowcaseContactSyncService.cls`
- `force-app/main/default/classes/ShowcaseContactSyncServiceTest.cls`

This example demonstrates:

- outbound HTTP callout
- Named Credential based endpoint configuration
- typed request and response wrappers
- mock-based callout testing
- integration-oriented Apex service design

### 3. Platform Event and Trigger-Based Processing

Representative files:

- `force-app/main/default/triggers/OrderEventTrigger.trigger`
- `force-app/main/default/classes/OrderEventTriggerTest.cls`
- `force-app/main/default/objects/Order_Event__e/Order_Event__e.object-meta.xml`

This example demonstrates:

- Platform Event definition
- trigger-based event processing
- event-driven follow-up automation
- testing with `EventBus.publish`

### 4. LWC + Apex Coordination

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

### 5. Additional Platform Samples Kept As Supporting Material

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
- avoid turning the repo into a dump of every historical sample

In practice, that means the core story of this repository is:

1. a curated set of platform and integration examples added to improve breadth
2. a deliberate review order so hiring teams can understand the signal quickly

## How To Review This Repository

Suggested review order:

1. `force-app/main/default/classes/ShowcaseContactRestResource.cls`
2. `force-app/main/default/classes/ShowcaseContactSyncService.cls`
3. `force-app/main/default/triggers/OrderEventTrigger.trigger`
4. `force-app/main/default/classes/ShowcaseContactController.cls`
5. `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`

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
