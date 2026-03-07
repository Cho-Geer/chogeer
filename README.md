# Salesforce CRM Application (Salesforce DX)

This project demonstrates a CRM-style Salesforce application built using **Salesforce DX**.

It includes custom business logic implemented with **Apex**, modern UI components using **Lightning Web Components (LWC)**, and workflow automation using **Salesforce Flow**.

The project showcases how Salesforce can be customized to support enterprise CRM scenarios.

---

# Overview

This repository contains a Salesforce DX project used to implement a simple CRM system.

The application supports:

- Account and contact management
- Custom business logic using Apex
- Lightning Web Components for UI
- Flow automation for workflow management
- Integration with external systems

The project follows Salesforce DX best practices for development and deployment.

---

# Tech Stack

Platform

- Salesforce Platform
- Salesforce DX

Backend Logic

- Apex

Frontend

- Lightning Web Components (LWC)
- Aura Components
- Visualforce

Automation

- Salesforce Flow

Development Tools

- Salesforce CLI
- ESLint
- Prettier
- Jest (LWC testing)

---

# System Architecture

```
Users
  │
  ▼
Salesforce UI
(LWC / Aura / Visualforce)
  │
  ▼
Apex Controllers
  │
  ▼
Salesforce Data Model
(Accounts / Contacts / Custom Objects)
  │
  ▼
External Integrations
(REST APIs)
```

---

# Project Structure

```
force-app
└── main
    └── default
        ├── apexClasses
        │   Apex business logic
        ├── lwc
        │   Lightning Web Components
        ├── aura
        │   Aura components
        ├── flows
        │   Flow automation
        └── objects
            Custom Salesforce objects
```

---

# Core Features

## CRM Data Management

Manage core CRM entities such as:

- Accounts
- Contacts
- Opportunities

---

## Apex Business Logic

Apex classes are used to implement:

- Validation logic
- Data processing
- Integration logic
- Business rules

---

## Lightning Web Components

Modern UI components built with LWC.

Features include:

- Interactive dashboards
- Data forms
- Reusable components

---

## Workflow Automation

Salesforce Flow is used to automate business processes such as:

- Record creation triggers
- Status updates
- Notifications

---

# Deployment

This project uses **Salesforce DX**.

Login to Salesforce org:

```
sfdx auth:web:login
```

Push source to org:

```
sfdx force:source:push
```

Run tests:

```
sfdx force:apex:test:run
```

---

# Testing

Testing includes:

- Apex unit tests
- LWC Jest tests

---

# Future Improvements

Possible improvements include:

- Enhanced CRM workflows
- External system integrations
- Advanced reporting dashboards
- Additional Lightning Web Components

---

# Author

Zixi Tao  
Senior Software Engineer  
14+ years experience building enterprise systems

GitHub  
https://github.com/Cho-Geer
