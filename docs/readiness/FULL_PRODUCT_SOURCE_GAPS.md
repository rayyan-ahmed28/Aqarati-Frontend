# Source-gap report

> Superseded on 2026-10-21 by `FRONTEND_GAPS_AND_API_BLOCKERS.md` (kept for history).

Updated 2026-10-16. What the app cannot do honestly yet, why, and what is needed. Nothing here was invented or faked; each item is either gated in the UI with an explanation or not present.

## Missing backend capabilities (front end only is in scope)

| Capability | Where it shows up | Current behaviour | Needed |
|---|---|---|---|
| Real authentication and session restore | Entire app | Demo auth; no session survives a reload; no router guards | Firebase and API wiring; `redirect` guards backed by the server |
| Listing service (create, manage, status) | Agent workspace; Aqary e-Broker | Agent "My listings" and "Listing status" say the service is not connected | API contract |
| Contact / lead events | Role homes, leads screens | "Not connected yet"; no chat, no history | Contact-event API |
| Professional engagement confirmation | Reviews eligibility, engagement screen | Unavailable state | Engagement API and eligibility rules |
| Project persistence, media, amenities | Developer wizard | In-memory demo repository; media and amenities disabled | Project API and upload contract |
| Company profile edit | Role homes, profile editor | Accepted as "awaiting review", not stored | Profile API and re-review behaviour |
| Viewings with real hosts | Viewing flow, Activity | Simulated in memory; host responses are QA-only controls | Viewing API |
| Enquiry and offer delivery | Property detail | Saved on the device only, and the UI says so | Delivery API |
| Portfolio publishing, moodboards | Architecture, Interior & Exterior | Shown as proposed | Product decision plus API |
| Notification delivery and preferences | Notifications inbox | In-app inbox from local state only; the screen says push is not connected | Push and device-token API; approved preference toggles |
| Password blocklist, consent versions | Signup | Not implemented | Service and approved legal versions |
| Account deletion endpoint and step-up re-authentication | Delete account | UI complete; production wiring reports "nothing was deleted"; no re-auth step | Endpoint, retention rules, re-authentication contract |
| Maintenance booking service and provider answers | Maintenance request | Requester side on an in-memory repository; the provider answers only through QA controls | Booking API, provider workspace, notifications |
| Maintenance provider to service mapping | Booking form | Any of the four services can be chosen for any maintenance provider | Provider services in the business model |
| Admin Web Console | Verification, moderation, invitations, ads, audit | Not built: `aqarati/apps/admin-web` holds README files only | Separate application and its own auth |
| Backend API (`aqarati/apps/api`) | All | Exists separately (105 files including migrations) but was not inspected; no contract from it was assumed | An endpoint-by-endpoint comparison against this app's repository interfaces |

## Unresolved product decisions

| Id | Question | Affects |
|---|---|---|
| D3 | Typed CR and licence numbers at signup | Company signup |
| D4 | Municipal licence expiry tracking | Documents, status |
| D8 | Several activity licences | Developer documents |
| D9 | Rejection reason codes beyond the architecture's closed list | Status, resubmission |
| D10 | 30-day re-apply rule after rejection | Status |
| D11 | Which architecture version is current (only v2.6 is present) | Everything sourced from it |
| #26 | e-Broker fee model (awaiting approval) | Aqary e-Broker |
| New | Notification preferences and push: in launch scope? | Notifications |
| New | Is Invest a transaction type? (the model has buy, rent, lease) | Home, search |
| New | Business bottom tabs from the references (Listings, Projects, Profile, Reviews): in scope? | Navigation |

## Product-truth rules enforced in code

No in-app messaging; no invented analytics, counts, ratings or lead histories; no success states for unconnected services (enquiry and offer say "saved on this device, not delivered"; viewing requests and signup show a DEMO notice); non-approved business grants never reach a business home or workspace; reviews require a confirmed engagement.

## Known limitations that are not decisions

- Tab scroll position is not preserved when switching tabs (needs a stateful shell route).
- Saved searches (as opposed to saved properties and recent searches) are not persisted.
- Arabic strings are drafts and need native review.
- The map is a keyless embed with no Google Maps features.
- The deployed Vercel site is the last pushed commit (`5a27396`) and contains none of the uncommitted work.
