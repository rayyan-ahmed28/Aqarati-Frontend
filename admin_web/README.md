# AQARATI Admin Web Console

A separate, desktop-first Flutter web application for AQARATI staff (architecture v2.4 section 89, option B: `aqarati-admin-web` at `admin.<client-domain>`). It is physically separate from the customer app: no admin code ships in the customer binary, and staff never sign in through the customer app.

> **Demo build.** The console runs on `DemoAdminApi` (in-memory). No real applicant, document, decision or email is involved. A DEMO bar is shown on every page while `kAdminDemo` is true (`lib/state/admin_state.dart`).

## Run

```bash
cd admin_web
flutter pub get
flutter run -d chrome
```

Build: `flutter build web` (output in `admin_web/build/web`).

### Demo accounts

| Role | Email |
|---|---|
| Reviewer | reviewer@aqarati.test |
| Senior Reviewer | senior@aqarati.test |
| Second Senior Reviewer (four-eyes) | senior2@aqarati.test |
| Super Admin | super@aqarati.test |
| Auditor | auditor@aqarati.test |

Password `Demo-Admin-2026`, authenticator code `123456` (also used for step-up). These are demo seed values only.

## What is built

| Area | Screens | Source |
|---|---|---|
| Authentication | Staff login, TOTP, session expired, step-up dialog (15 min), sign-out | §44, §50, §95.5 |
| Dashboard | Open items, oldest item (18 h warning / 24 h breach colours), awaiting second approval, average turnaround, items by type, decisions | §89 (recommended) |
| Verification queue | Priority order (resubmissions → businesses → listings, oldest first), filters (type, claim, open), search, age, claim holder | §34.1, §50.3 |
| Review item | Submitted fields beside streamed, watermarked, per-view-audited documents; checklist per entity type; approve / request resubmission / reject with the closed list of 12 reason codes; note validation (no ID numbers); claim (30 min) / release / escalate; four-eyes for developers and Aqarati Brokers; decision history; optimistic version lock | §34.2, §50.1–50.3 |
| Suspension & reinstatement | Search, suspend with reason (step-up), reinstate (step-up), cascade explained | §48.7 |
| Provider invitations | Create, list, revoke; duplicate guard | §19.9, §35 |
| Review moderation | New / edited reviews (publish or not), reported reviews (keep or remove) | §87 |
| Ad banners | Create banner → verification queue → scheduled; pause / resume | §84 |
| Audit log | Append-only, filterable, read-only for everyone | §51 |
| Admin users | Create, change role, enable / disable (not yourself) | §47 |
| Roles & permissions | RBAC matrix, reason codes, checklists (read-only configuration) | §47, §50 |
| States | Loading skeletons, empty, error + retry, forbidden-for-role, not found, confirmation dialogs | — |

## Rules enforced by the service layer (not just hidden in the UI)

Every write goes through `AdminApi`, which checks the role permission, step-up freshness, the claim holder, self/related-account conflicts, the four-eyes rule (different senior approver), checklist completion, reason codes, note safety and the item version, and writes an audit row. `test/admin_service_test.dart` covers these rules.

## Derived decisions (not fixed by the architecture)

- Review moderation is allowed for Reviewer and above; ad management for Senior Reviewer and Super Admin.
- Invitation links last 7 days.
- Aqarati Broker grants are treated like developers for four-eyes (Senior approval required, §83).

## Blocked by missing services

Real admin authentication (separate Identity Platform tenant + TOTP), the `/api/v1/admin/*` endpoints, document streaming from Oman storage, creative uploads, email delivery of invitations, and configuration editing (reason-code templates, checklists) all need the backend. The demo service stands in for them and says so.
