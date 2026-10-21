# Screen navigation and action matrix (completion pass)

Every interactive control on the screens added or changed in this pass. Columns: control → result (navigate / submit / select / sheet / external / disabled-with-reason), loading, success, failure, Back. Pre-existing screens keep their matrices in `FULL_PRODUCT_INTERACTION_MATRIX.md`, `docs/development_building/INTERACTION_MATRIX.md` and `docs/role_home_pages/HOME_PAGE_INTERACTION_MATRIX.md`.

Rules applied everywhere: buttons disable while their operation runs (no duplicate submission); success copy appears only after the repository returns; failures leave input intact and show a banner with a real retry; Back uses `aqBack(context, fallback)` (pop, or a specific parent when opened by deep link).

## Help (`?`)

| Control | Result | Success / failure | Back |
|---|---|---|---|
| `?` next to a term | opens short sheet (root navigator) | — | sheet close / backdrop / drag returns to the same scroll position |
| Learn more | closes sheet, pushes `/help/:id` | unknown id → recovery page with "Open Help & guides" | pops to the screen that opened the sheet |
| Related topic row | pushes `/help/:id` | — | pops back to previous guide |
| Help & guides row (Account, Settings) | pushes `/help` | — | `/app/account` fallback |

`?` placements: Home (Browse markets, D&B, Maintenance), Explore (Maintenance), D&B home, filter sheet, viewing availability, calculator disclaimer, listing wizard (market, listing type, size, after-submit note), My listings, listing detail, sell entry, broker programme / directory / profile, engagement pages, review composer / My reviews, provider invitation + home.

## Listings and Aqary e-Broker

| Screen | Control | Result | Loading / success / failure | Back |
|---|---|---|---|---|
| Agent home | My listings tile | push `/listings` | — | pop |
| Agent home | New listing | push `/listings/new?channel=agent` | — | pop |
| Account tab | My listings / Sell with Aqary e-Broker | push `/listings` / `/sell` | — | pop |
| Property types | Sell with Aqary e-Broker | push `/sell` | — | pop |
| My listings | New listing (approved agent only) | push wizard (agent) | — | `/app/account` |
| My listings | Sell with Aqary e-Broker | push `/sell` | — | — |
| My listings | filter pills | select (state kept while the screen is in the stack) | — | — |
| My listings | draft row | push wizard with `draft=` (values restored) | skeleton | — |
| My listings | listing row | push `/listings/:id` | — | — |
| My listings | signed out | Log in → `/login` | — | — |
| Wizard | market / type / sub-type pills | select; changing market clears dependent choices | — | — |
| Wizard | Governorate / Wilayat fields | choice sheet; wilayat disabled until a governorate is chosen (hint explains) | — | — |
| Wizard | Bedrooms / Bathrooms | choice sheet | — | — |
| Wizard | Add photos | file picker (JPG/PNG ≤ 10 MB, signature checked) | button spinner; bad file → banner | — |
| Wizard | photo ✕ | removes that photo (announced count) | — | — |
| Wizard | Use sample photos / Attach sample file | QA builds only | — | — |
| Wizard | Choose file / Replace (deed, authorisation) | file picker (PDF/JPG/PNG ≤ 10 MB) | spinner; bad file → banner | — |
| Wizard | Continue | validate step → next step (directional slide) | invalid → inline errors + banner + announcement; stays on step | — |
| Wizard | Back (bar or top) | previous step, values kept | — | step 1: leave sheet |
| Wizard | Save draft | repository `saveDraft` | snackbar "Draft saved" | — |
| Wizard (step 1, unsaved) | top Back / system back | sheet: Save draft and leave / Leave without saving / Cancel | — | `/listings` |
| Wizard review | Edit links | jump to that step | — | — |
| Wizard review | fee checkbox (e-Broker), declaration | toggle | — | — |
| Wizard review | Submit for review | `submit` with idempotency key | spinner; → `/listings/:id/submitted` (replace); duplicate deed → calm block; not allowed → reason; network → retry | — |
| Receipt | View listing status | replace with `/listings/:id` | — | — |
| Receipt | Go to my listings | `go('/listings')` | — | — |
| Listing detail | Fix and resubmit | push `/listings/:id/fix` | — | — |
| Listing detail | Renew for 90 days | `renew` | spinner; snackbar; conflict → banner | — |
| Listing detail | Edit listing | push `/listings/:id/edit` (location, facts, photos, review) | result snackbar names immediate vs reviewed fields | — |
| Listing detail | Mark as sold / rented, Withdraw | confirmation sheet → `setLifecycle` | spinner; snackbar; conflict → banner | — |
| Listing detail | Start a new listing (rejected) | push `/sell` or wizard | — | — |
| Listing detail | QA tools | simulate reviewer / expiry / hide / change-set decision | — | — |
| Listing detail (missing id) | Go to my listings | `go('/listings')` | — | — |
| Sell entry | Start selling | no photo ID → `/sell/identity`; else wizard (e-Broker) | — | `/app/home` |
| Sell entry (guest) | Log in / Create an account | `/login` / `/onboarding/purpose` | — | — |
| Seller photo ID | Upload photo ID | picker → `uploadSellerId` | spinner; card turns "Uploaded" (announced, no snackbar over the CTA) | `/sell` |
| Seller photo ID | Continue to property details | disabled until uploaded; then replace with wizard | — | — |

## AqaratiBroker

| Screen | Control | Result | Back |
|---|---|---|---|
| Home / Explore | Aqarati Broker card | push `/brokers` | pop |
| Programme | Find an Aqarati Broker | push `/brokers/all` | `/app/home` |
| Programme | Sell my own property | push `/sell` | — |
| Programme | Learn more (vs e-Broker) | push `/help/brokers` | — |
| Directory | search field, governorate pills | filter (kept while the screen is in the stack) | `/brokers` |
| Directory | Clear filters (empty state) | reset | — |
| Directory | broker row | push `/brokers/:id` | — |
| Profile | listing card | push `/property/:id` | `/brokers/all` |
| Profile | Contact | signed in → contact sheet; guest → sign-in sheet | — |
| Contact sheet | Call / WhatsApp row | copy number; snackbar; missing WhatsApp row is information only | sheet dismiss |
| Property detail | Listed by an Aqarati Broker | push `/brokers/:id` | pop |

## Engagements and reviews

| Screen | Control | Result | Loading / failure | Back |
|---|---|---|---|---|
| D&B profile (Reviews tab) | Confirm an engagement | push `/engagements/new?pro=` | — | pop |
| D&B profile | Write a review | push composer (professional) | — | — |
| D&B review card | Report | push `/reviews/report` | — | — |
| Engagement request | Send engagement request | `request` → replace with `/engagements/:id` | spinner; duplicate → "Open it"; ineligible → reason; network → retry | `/build/pro/:id` |
| Engagement request (guest) | Log in | `/login` | — | — |
| My engagements | filter pills; row | select; push detail | — | `/app/account` |
| Engagement detail | Yes, we worked together (waiting for me) | `confirm` | spinner; conflict → banner | `/engagements` |
| Engagement detail | Write a review (confirmed, window open) | push composer | — | — |
| Engagement detail | Send a new request (closed states) | push request | — | — |
| Engagement detail | Cancel request | confirmation sheet → `cancel` | spinner | — |
| Engagement detail | View company | push `/build/pro/:id` | — | — |
| Composer gates | Log in / Confirm an engagement / Edit my review / See my reviews | as labelled | — | `/reviews/mine` |
| Composer | stars, comment | select / type (counter, inline errors after first attempt) | — | — |
| Composer | Preview | validate → preview step | errors inline | — |
| Composer (preview) | Back to editing / system back | compose step | — | — |
| Composer (preview) | Submit for moderation | `submit` / `edit` | spinner; not eligible / already reviewed → banner | — |
| Done | See my reviews / Done | replace `/reviews/mine` / back | — | — |
| My reviews | Edit (only if allowed) | push edit composer | — | `/app/account` |
| Report | Send report | validate → confirmation → `report` → receipt | spinner; already reported → banner | `/app/explore/build` |
| Maintenance detail (completed) | Write a review | push composer (provider) | — | — |
| Viewing (completed) | Rate / Write a review | composer (seller = host) | — | `/viewings/:id` |

## Maintenance provider

| Screen | Control | Result | Back |
|---|---|---|---|
| Invitation | Accept invitation | step 1 | `/entry` |
| Invitation steps | Continue / Back | validate → next / previous (values kept) | step 0 → overview |
| Invitation review | Create provider account | `accept` → `/provider/documents` | — |
| Invitation (expired / used / unknown) | Log in (used) | `/login` | `/entry` |
| Documents | Choose file per document | picker → `upload` | `/provider/status` |
| Documents | Submit for verification | needs both → `submit` → `/provider/status` | — |
| Status | Your documents / Open provider workspace | as labelled | `/app/account` |
| Status | QA reviewer buttons | simulate decision | — |
| Home | request row; See all requests | push detail / list | `/app/account` |
| Requests | tab pills; row | select; push detail | `/provider` |
| Request detail | Copy customer number | clipboard + snackbar | `/provider/requests` |
| Request detail | Confirm / Decline / Mark as completed / Cancel job | confirmation → `decide`; Mark completed disabled before the preferred day (explained) | — |
| Workspace (not approved) | Verification status | push `/provider/status` | — |

## Account, settings, system

| Screen | Control | Result | Back |
|---|---|---|---|
| Account tab | each row | push its route | — |
| Account tab | Sign out | confirmation sheet → sign out → `/entry` | — |
| Account tab | Delete account | push `/account/delete` | — |
| Profile | Edit profile | push edit | `/app/account` |
| Edit profile | Change email | sheet → verify-before-update → snackbar | — |
| Edit profile | Save changes | `updateProfile` (no changes → snackbar) | unsaved → discard confirmation |
| Organisation | View verification status / Edit company profile / Preview public profile | `/verification` / workspace profile editor / `/build/pro/:id` | `/app/account` |
| Settings | Light / Dark / Same as device; English / العربية | change immediately (animated palette; route and inputs kept); persisted on device | `/app/account` |
| Settings | Notifications / Security / Privacy & legal / Help | push | — |
| Notification settings | Open notifications | push `/notifications` | `/account/settings` |
| Security | Change password | confirmation → reset email → snackbar | `/account/settings` |
| Security | Sign out of all devices | destructive confirmation → `signOutEverywhere` → `/entry` | — |
| Privacy & legal | Terms / Privacy / Delete account | push | `/app/account` |
| Session expired | Sign in again / Browse without signing in | `/login` / `/app/home` | — |
| Forced update | I have updated, check again | re-fetch config | none (blocking) |
| Notifications | row | marks read, opens the record (`/listings/:id`, `/engagements/:id`, `/reviews/mine`, `/provider/status`, `/provider/requests/:id`, existing viewing / booking / verification targets); missing record → that screen's not-found recovery | — |

## Admin Web Console

| Screen | Control | Result | Failure |
|---|---|---|---|
| Login | demo account chip | fills email + password | — |
| Login | Continue | credentials → `/totp` | invalid → generic message |
| TOTP | Verify and sign in | → `/dashboard` | invalid code → message |
| Sidebar | entries (role-filtered) | `go(path)` | forbidden page if opened directly |
| Sidebar | Sign out | end session → `/login` | — |
| Dashboard | Open queue | `/queue` | — |
| Queue | search, type, claim filter, open-only | filter | — |
| Queue | row | `/queue/:id` (audited open) | — |
| Item | Open document | streamed view with watermark (audited) | role without permission: hidden + refused by service |
| Item | Claim item | claim 30 min | claimed by other / self-review → message |
| Item | Pass / Fail per checklist item | select (claim holder only) | — |
| Item | Approve / Request resubmission / Reject | select outcome | — |
| Item | Reason code, note | select / type (helper explains note rules) | — |
| Item | Submit decision | confirmation → step-up if needed → decide | checklist, reason, version, four-eyes, note → specific messages |
| Item | Release claim / Escalate to Senior | as labelled | — |
| Accounts | Suspend / Reinstate | reason dialog or confirmation → step-up → action | — |
| Invitations | Create invitation / Revoke | create / confirmation → revoke | duplicate → message |
| Moderation | Publish / Do not publish / Keep published / Remove | moderate (Remove confirms) | illegal transition → message |
| Ads | Choose dates / Submit for review / Pause / Resume | create → queue; pause / resume | validation → message |
| Audit | filter, Refresh | read-only | — |
| Admin users | Create / role dropdown / Disable / Enable | as labelled (not yourself) | duplicate → message |
| Session expiry (any call) | — | `/session-expired` | — |
