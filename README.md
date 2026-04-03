# Salesforce Platform Showcase (chogeer)

This repository is a **Salesforce DX portfolio project** focused on customer community/login experiences and controller-driven UI patterns.

It is positioned as a practical showcase for:

- Apex controller development
- Experience Cloud style login / registration / password flows
- UI-to-Apex interaction patterns across Visualforce, Aura, and LWC
- Security-aware controller design and test coverage

---

## Repository Focus

This is not a single monolithic business product; it is a curated Salesforce codebase that demonstrates implementation patterns commonly used in real-world Salesforce delivery.

Primary showcase areas:

- Authentication-related flows (login, forgot password, change password, self registration)
- Experience Cloud compatible pages/components
- Apex + UI coordination patterns
- Mixed UI stack support (Visualforce, Aura, LWC)

---

## Key Apex Controllers

Representative classes in this repo include:

- `force-app/main/default/classes/LightningLoginFormController.cls`
- `force-app/main/default/classes/ChangePasswordController.cls`
- `force-app/main/default/classes/ForgotPasswordController.cls`
- `force-app/main/default/classes/SiteLoginController.cls`
- `force-app/main/default/classes/SiteRegisterController.cls`

Related test classes are also included in the same folder.

---

## UI Assets Included

### Visualforce Pages

Examples under `force-app/main/default/pages/`:

- `SiteLogin.page`
- `SiteRegister.page`
- `ForgotPassword.page`
- `ChangePassword.page`
- `CommunitiesLogin.page`
- `CommunitiesSelfReg.page`

### Aura Components

Examples under `force-app/main/default/aura/`:

- `loginForm`
- `forgotPassword`
- `selfRegister`

### Lightning Web Components

Examples under `force-app/main/default/lwc/`:

- `testTrack`
- `tabSet`
- `openNewWindow`

---

## Tech Stack

- Salesforce Platform
- Salesforce DX (SFDX project)
- Apex
- Visualforce
- Aura Components
- Lightning Web Components
- JavaScript (ESLint + Jest for LWC)

---

## Local Development

### 1) Install dependencies

```bash
npm install
```

### 2) Authenticate to a Salesforce org

```bash
sfdx auth:web:login
```

### 3) Push source

```bash
sfdx force:source:push
```

### 4) Run checks

```bash
npm run lint
npm run test:unit
```

---

## Career Artifacts (for remote job applications)

This repo also includes ready-to-use English artifacts:

- `career/resume-v1.md`
- `career/linkedin-v1.md`
- `career/interview-answers-v1.md`

These files are prepared for a Salesforce Platform / Integration oriented job search narrative.

---

## Author

**Zach Tao (Zixi Tao)**  
Senior Salesforce Platform / Integration Engineer  
GitHub: https://github.com/Cho-Geer
