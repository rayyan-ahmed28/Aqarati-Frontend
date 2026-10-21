# Full product screen inventory

Updated 2026-10-21 from the actual repository (`SyedAmeenAli/Aqarati-Final-UI-UX`, branch `main`, base commit `e0a6bc3`, plus the uncommitted completion pass described in `IMPLEMENTATION_LOG.md`). Routes were counted from source: **112 literal `GoRoute` paths + 6 sign-up paths generated from `signupPurposeOptions` = 118 customer-app routes**, and **13 routes in the separate Admin Web Console** (`admin_web/`).

Status words: **verified** (source + automated test + browser walk agree), **implemented, not verified** (source + tests, no browser walk), **partial**, **demo-only** (works on an in-memory repository and says so on screen), **blocked** (needs an API or contract that does not exist), **decision needed** (product decision open), **not in scope**.

Every customer screen below that runs on simulated data shows the DEMO notice while `kUseDemoBackend` is true. "Demo-only" therefore describes the data source, not the UI completeness.

Evidence keys: **T** automated test file; **M** layout matrix (`app_matrix_test.dart` or `completion_matrix_test.dart`: 320 px, dark, Arabic RTL, 200 % text); **B** browser walk of the QA build on 2026-10-21.

## 1. Entry, identity, sign-up (existing, re-verified by tests only)

| Screen | Route | Status | Evidence |
|---|---|---|---|
| Entry / launch film | `/entry` | verified | T, B (film + Skip) |
| Purpose selection (six paths) | `/onboarding/purpose` | verified | T |
| Six sign-up forms | `/signup/*` (6) | demo-only | T |
| Phone OTP, email verification, account active | `/otp`, `/verify-email`, `/account/active` | demo-only | T |
| Login, forgot / reset password | `/login`, `/forgot-password`, `/reset-password` | demo-only | T, M |
| Terms, Privacy | `/legal/terms`, `/legal/privacy` | partial: shell only, legal text not supplied | M |
| **Forced update (version gate)** | wraps the app (`AQVersionGate`) | **new**, implemented, not verified in browser (QA: `?minVersion=9.9.9`) | T `completion_flows`, M |
| **Session expired** | `/session-expired` | **new**, implemented | M |
| **Maintenance provider invitation** | `/invite/:token` | **new**, demo-only (`demo-invite`, `expired`, `used`) | T, M |

## 2. Business verification (existing)

| Screen | Route | Status |
|---|---|---|
| Verification intro, documents, review, submitted | `/onboarding/*` | demo-only (T) |
| Status (all grant states), details, resubmission, approved, summary, activation | `/verification*`, `/workspace/activation` | implemented, demo-only (T) |

## 3. Six role homes (existing, entry points extended)

| Home | Status | Change in this pass |
|---|---|---|
| Buyer | verified (T, M, B) | Aqarati Broker tile → `/brokers`; D&B section → `/app/explore/build`; `?` help on Browse, D&B, Maintenance; provider banner when the account holds a provider grant |
| Agent (with Buyer ↔ Agent switcher) | verified (T, B) | **My listings tile now works**; live listing counts by state; New listing CTA |
| Developer, Construction, Architecture, Interior & Exterior | verified (T) | unchanged |
| Maintenance provider (home banner → workspace) | new, demo-only | — |

## 4. Property discovery and listing lifecycle

| Screen | Route | Status | Evidence |
|---|---|---|---|
| Explore, search, markets, results, map, detail, saved, compare, calculators | existing routes | verified (layout) on mock data | T, M, B |
| Property detail: Aqarati Broker badge + link | `/property/:id` | new, demo data | T (matrix), B |
| **My listings** (filters: all, live, in review, needs action, drafts, closed) | `/listings` | new, demo-only | T, M |
| **Listing wizard** (property, location, price + facts, photos, ownership, review) | `/listings/new?channel=agent|ebroker&draft=` | new, demo-only; map pin picker not connected | T (full journey), M, B |
| **Listing receipt** ("in review", never "live") | `/listings/:id/submitted` | new | T |
| **Listing status + lifecycle actions** (sold, rented, withdraw, renew, edit, fix) | `/listings/:id` | new, demo-only; reviewer decisions via QA tools | T |
| **Fix and resubmit** | `/listings/:id/fix` | new | T (logic) |
| **Edit after approval** (material change set vs immediate) | `/listings/:id/edit` | new | T (logic) |

## 5. Aqary e-Broker (selling)

| Screen | Route | Status |
|---|---|---|
| **Sell entry** (how it works, who can use it, fee position, sign-in gate) | `/sell` | new; fee shown as "awaiting approval", no amount (decision #26) — T, B |
| **Seller photo ID (once)** | `/sell/identity` | new, demo-only — T |
| Property / location / deed / photos / review / submit / receipt / status / resubmission / lifecycle | shared listing routes with `channel=ebroker` | new, demo-only — T |

## 6. AqaratiBroker programme

| Screen | Route | Status |
|---|---|---|
| **Programme introduction + badge meaning + pending terms** | `/brokers` | new — T, M |
| **Broker directory** (search, governorate filter, counts, empty + clear) | `/brokers/all` | new, demo roster — T, M |
| **Broker profile** (badge, approved listings, honest review state, contact gated by sign-in) | `/brokers/:id` | new, demo roster — T, M, B |

## 7. Engagements and reviews

| Screen | Route | Status |
|---|---|---|
| **Engagement request** (rules: 14-day confirm, 60-day review window) | `/engagements/new?pro=` | new, demo-only — T, M |
| **My engagements** (filters) | `/engagements` | new — M |
| **Engagement detail** (waiting for company / for me, confirmed, expired, declined, cancelled; cancel confirmation; QA professional answer) | `/engagements/:id` | new — T |
| Company-side engagement confirmation | `/workspace/engagements/:id` | existing; still "not connected" in the D&B demo capabilities |
| **Review composer** (eligibility gates → stars + 10–500 chars → preview → "submitted for moderation") | `/reviews/write?kind=professional|provider|seller` | new — T |
| **Edit review** (only when the service allows) | `/reviews/:id/edit` | new — logic T |
| **My reviews** (moderation status, QA moderation tools) | `/reviews/mine` | new — M |
| **Report review** (reason in own words, confirm, receipt, already-reported) | `/reviews/report` | new — T |
| Viewing → review the host | `/viewings/:id/review` | **replaced** the "coming soon" page with the composer (seller target) |
| Maintenance → review the provider | `/bookings/:id` | rewired to the composer |

## 8. Maintenance

| Screen | Route | Status |
|---|---|---|
| Customer: discovery, provider profile, request, review, detail, cancel, Activity list | existing | demo-only (T) |
| **Provider: invitation acceptance (account, company, services + wilayats, review)** | `/invite/:token` | new, demo-only — T |
| **Provider: documents (CR + municipal licence)** | `/provider/documents` | new — T (logic) |
| **Provider: verification status (+ QA reviewer decisions)** | `/provider/status` | new — M |
| **Provider: home** (new / confirmed counts) | `/provider` | new, approved-only guard — T, M |
| **Provider: requests** (new, confirmed, history) | `/provider/requests` | new — M |
| **Provider: request detail** (copy customer number, confirm, decline, complete from the preferred day, cancel) | `/provider/requests/:id` | new — T (logic) |

## 9. Notifications, Activity, account

| Screen | Route | Status |
|---|---|---|
| Notification inbox | `/notifications` | extended: listings, engagements, reviews, provider grant and provider requests, each deep-linking to the record; sources load in parallel |
| **Notification settings** (mandatory notices listed; optional: none defined; push not connected) | `/account/notification-settings` | new |
| Account tab | `/app/account` | **rebuilt**: profile header, grouped rows (account, activity, preferences, help/legal), sign-out confirmation, delete |
| **Personal profile** | `/account/profile` | new |
| **Edit profile** (names via PATCH /me; email via verify-before-update; phone explained) | `/account/profile/edit` | new, demo-only — T (logic) |
| **Organisation** (company record, status, documents metadata, edit link, public preview, single-owner note) | `/account/organisation` | new |
| **Settings** (light / dark / same as device, language, notifications, security, legal, help, about) | `/account/settings` | new; theme + language now persist on device — T |
| **Privacy & legal** (terms, privacy, consent, data, delete) | `/account/privacy` | new |
| **Security** (password link, sign out of all devices; device list unavailable) | `/account/security` | new, demo-only |
| Delete account | `/account/delete` | existing; demo success now states that nothing was deleted on a server |

## 10. Help

| Screen | Route | Status |
|---|---|---|
| `?` button + short sheet + Learn more | everywhere listed in the action matrix | new — T |
| **Help & guides** (13 topics, 3 groups, support placeholder) | `/help` | new — M |
| **Guide article** (+ related topics; not-found recovery) | `/help/:id` | new — T, M |

## 11. Admin Web Console (separate app, `admin_web/`)

| Screen | Route | Status |
|---|---|---|
| Staff login, TOTP, session expired, step-up dialog | `/login`, `/totp`, `/session-expired` | demo-only — T, B |
| Dashboard | `/dashboard` | demo-only — T, B |
| Verification queue + filters | `/queue` | demo-only — T |
| Review item: fields, watermarked document viewer, checklist, decisions, reason codes, claim / release / escalate, four-eyes, history | `/queue/:id` | demo-only — T, B |
| Suspension & reinstatement | `/accounts` | demo-only — T |
| Provider invitations | `/invitations` | demo-only — T |
| Review moderation | `/moderation` | demo-only — T |
| Ad banners | `/ads` | demo-only — T |
| Audit log | `/audit` | demo-only — T |
| Admin users | `/admins` | demo-only — T |
| Roles & permissions, reason codes, checklists | `/roles` | read-only — T |
| Forbidden-for-role, not found, empty, error | all | T |

## 12. Not in scope (by source)

Organisation team members (REMOVED from MVP, single owner), Marketplace (FUTURE), loan application, in-app chat, calendar sync, payments / deposits / escrow.

## Totals

- Customer app: 118 routes. New in this pass: 34 routes + the version gate + the `?` sheet.
- Admin console: 13 routes, all new.
- Still **missing / blocked**: real backend for every demo repository; map pin picker for listings; Aqarati Broker grant creation (Super Admin flow exists only as a permission); company-side engagement API; lead events; push delivery; legal text; consent versions; device list.
