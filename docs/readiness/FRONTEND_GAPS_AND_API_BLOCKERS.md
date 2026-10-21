# Frontend gaps and API blockers

Updated 2026-10-21. Supersedes the "missing" rows of `FULL_PRODUCT_SOURCE_GAPS.md` (kept for history). Nothing below is faked in the UI: each item is either a demo repository that says DEMO on screen, an explicit "not available" explanation, or a disabled control with its reason.

Authority used: `AQARATI_Complete_System_Architecture_v2.4.pdf` (supplied with the handoff) and the 100-page frontend blueprint. The handoff notes mention a possible v2.6 elsewhere; it is not in this repository, so v2.4 was used and existing code comments that cite "v2.6" were left as they were. **Decision needed: confirm which architecture version is current.**

## 1. Backend contracts the frontend is ready for (blocked until the API exists)

Every new feature talks to an abstract repository with an `Unavailable…` implementation (all calls fail like an offline request) and a `Demo…` implementation used while `kUseDemoBackend` is true.

| Capability | Frontend contract (file) | Endpoint(s) in the architecture | Notes |
|---|---|---|---|
| Listings (create, drafts, resubmit, lifecycle, renew, edit / change set, seller photo ID) | `features/listings/listing_repository.dart` | POST /properties, PATCH /properties/:id, POST /properties/:id/status, POST /properties/:id/renew, POST /documents | Draft storage endpoint is not defined (drafts are local to the repository). Photo upload (`/properties/:id/images`) not wired; files are checked client-side only. |
| Aqarati Broker directory + broker listings | `features/broker/broker_data.dart` | GET /professionals (aqarati_broker), GET /properties?broker= | Rating needs published broker reviews; none exist in demo, so the profile shows "No published reviews yet". |
| Client-side engagements | `features/engagement/engagement_repository.dart` | not in the endpoint catalog (professional_engagements table only) | **Blocked:** request / confirm / cancel endpoints must be defined. |
| Company-side engagement confirmation | `devbuild/db_repository.dart` (`caps.engagements = false`) | same as above | Still shown as unavailable in the D&B workspace. |
| Reviews: submit, edit, mine, report | `features/reviews/review_repository.dart` | POST /reviews, POST /reviews/:id/reports | "My reviews" list and edit endpoints are not in the catalog. |
| Profile update, sign out everywhere | `data/api/account_api.dart` | PATCH /me, POST /auth/log-out-all | Email change uses the Firebase contract already in `AuthRepository`. |
| Provider invitation + onboarding + workspace | `features/provider/provider_data.dart` | POST /invitations/:token/accept, POST /documents, provider booking endpoints | Provider-side booking list / decision endpoints are not in the catalog (only POST /maintenance/bookings). |
| App config / version gate | `features/system/version_gate.dart` | GET /app/config | Store URLs unknown; the forced-update screen says so. |
| Notification inbox | built from the repositories above | GET /notifications, POST /notifications/:id/read | Push (FCM) and device registration not connected. |
| Admin console | `admin_web/lib/data/admin_api.dart` | /api/v1/admin/* | Separate auth tenant + TOTP, document streaming, invitation email, creative upload, configuration editing all need the backend. |

## 2. Product decisions still open (shown honestly in the UI)

| # | Decision | Where it shows | Current UI |
|---|---|---|---|
| 26 | Aqary e-Broker fee model ("up to 2 %" proposed, PENDING) | Sell entry, wizard review | "Fee awaiting approval, no amount shown"; the person acknowledges the notice. A real submission must show the approved fee before it can be published. |
| 40 | Aqarati Broker programme terms (commission, extra vetting, scope) | Broker programme page | "Programme terms awaiting approval" card. |
| — | Who creates Aqarati Broker grants in the console | Admin | Permission `createBrokerGrant` exists (Super Admin); no creation screen because the programme rules are pending. |
| — | Report reason codes for reviews | Report review | Free-text reason (10–500 characters); no invented code list. |
| — | Optional notification categories | Notification settings | "None defined yet"; mandatory categories listed. |
| — | e-Broker market scope | Wizard | Taxonomy lists e-Broker under Residential only, so owner sales are Residential `buy`. Confirm whether other markets are allowed. |
| — | Listing draft persistence on the server | Wizard "Save draft" | Saved in the repository for the session (demo). |
| — | Invitation link validity | Admin invitations | 7 days (derived). |
| — | Moderation and ad-management roles | Admin | Reviewer+ moderate; Senior / Super manage ads (derived, documented in the console). |
| — | Senior reviewer for Aqarati Broker approvals | Admin four-eyes | Treated like developers (second, different senior approval). |
| D11 | Architecture version (v2.4 vs v2.6) | Everything | v2.4 used. |
| — | Design-system palette | Brand | v2.4 §16 lists a teal palette; the repository's approved brand tokens (mocha / ivory) were kept per the handoff brief. |
| — | Listing attribute matrix details | Wizard | §16.2 table is partly unreadable in the PDF; matrix in `listing_models.dart` is marked DERIVED. |
| — | BUY / RENT / INVEST vs the older `TransactionType { buy, rent, lease }` | Discovery (old model) | New listing model has buy / rent / invest only. The legacy discovery model still has `lease` (mock shop p6); left untouched and flagged. |

## 3. Frontend gaps that remain (not blocked by an API)

| Gap | Why it is not done |
|---|---|
| Map pin picker in the listing wizard | Needs Google Maps key + place picker; the step explains the pin is set with the reviewer. |
| Push notification permission prompt | No FCM wiring in this repository. |
| Tab scroll position preservation across tabs | Pre-existing limitation (needs StatefulShellRoute). |
| Arabic copy review | All new Arabic strings are drafts. |
| Snackbars over pinned bottom bars | Some success snackbars briefly overlap the bottom action bar on standalone pages (cosmetic; the e-Broker photo-ID case was changed to an announcement). |
| `ReviewScreen` (old "how reviews work" page) | No longer linked from the app (replaced by the composer) but kept because `listing_pages_test.dart` covers it. |
| Developer project media / amenities | Pre-existing, blocked by the project upload API. |
