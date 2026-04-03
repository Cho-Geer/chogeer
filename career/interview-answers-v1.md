# Interview English Answers v1 (Booking / Auth / Admin)

## 1) "Tell me about your booking system architecture."

My booking system is split into a Next.js frontend and a NestJS backend.

On the backend, I use modular services for auth, users, bookings, services, and time slots, with Prisma for data access and PostgreSQL as the primary store. Redis is used where low-latency state or caching is helpful. I keep API contracts explicit and stable so the frontend can evolve independently.

On the frontend, I use TypeScript with a service-layer approach for API calls, plus Redux Toolkit for predictable state transitions. This separation helps me maintain features like booking creation, booking management, and admin operations without tightly coupling UI and backend logic.

## 2) "How did you design authentication and security?"

I designed authentication around cookie-based sessions with refresh flow support, and I paid attention to CSRF protection because cookies are involved.

I also use role-aware route/API protection so admin capabilities are isolated from standard user flows. In practice, this means both frontend route guards and backend authorization checks are aligned. My goal is not only to make auth work, but to make it maintainable and easy to audit when requirements change.

## 3) "How does admin flow differ from user booking flow?"

User flow is optimized for simple booking actions: browse slots, submit booking requests, and review personal booking history.

Admin flow adds operational controls: managing services, time slots, and booking statuses. The design principle is RBAC + clear domain boundaries. User APIs and admin APIs are separated so that permissions, validations, and error handling remain explicit.

## 4) "How does your Salesforce background help this system?"

Salesforce work trained me to think in process automation, integration contracts, and operational reliability. I apply the same mindset here:

- Define clear boundaries between modules and systems.
- Build integration points intentionally, not ad hoc.
- Keep security and supportability as first-class requirements.

That is why I position myself as a Salesforce Platform/Integration engineer who can also deliver full-stack execution when needed.

## 5) "Flow vs Apex: how do you decide?"

I use Flow for transparent, maintainable business automation when requirements are straightforward and admin visibility is important.

I use Apex when I need stronger control: complex logic, external callouts, reusable service abstractions, or stricter testability/performance handling. In real projects, I often combine both—Flow for orchestration and Apex for core logic/integration points.

## 6) "What integration work have you done recently?"

In recent Salesforce projects, I implemented callout APIs and worked on integration design between Salesforce and external systems, including migration-related scenarios. I also handled test planning and post-release issue response, so I am comfortable owning integration quality beyond initial development.
