# Role capability matrix

Updated 2026-10-21. Source: architecture v2.4 §5, §18.3, §19, §47. A role chosen at sign-up is **not** a grant: business features open only for an **approved** grant (`resolveHome`, `DbGuard`, `canUseChannel`, provider gate). Every check is repeated by the (future) API; hiding a control is never the control.

## Customer app

| Capability | Guest | Buyer (User to Shop) | Agent (approved) | Agent (pending / rejected / suspended) | Developer (approved) | Construction / Architecture / Interior & Exterior (approved) | Maintenance provider (approved, invited) |
|---|---|---|---|---|---|---|---|
| Browse approved properties and directories | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Contact details, call / WhatsApp | sign-in prompt | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Request viewings, maintenance bookings | sign-in prompt | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Aqary e-Broker (sell own property) | sign-in prompt | ✓ (photo ID once) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Agent listings (on behalf of owners) | — | — | ✓ (My listings, New listing) | — (status banner) | — | — | — |
| Buyer ↔ Agent switcher | — | — | ✓ | — | — | — | — |
| Home | buyer | buyer | agent console | buyer + status banner | developer home | studio / company home | buyer home + provider banner |
| Company profile + public preview | — | — | — (agents have no directory profile) | — | ✓ | ✓ | — |
| Developer projects (create / edit / resubmit) | — | — | — | — | ✓ own only | — | — |
| Engagement request (as client) | sign-in | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Confirm engagements (as company) | — | — | — | — | blocked (no API) | blocked (no API) | — |
| Write reviews | sign-in | after completed viewing / booking or confirmed engagement | same | same | same | same | same |
| Report a published review | sign-in | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Provider workspace (requests, confirm, decline, complete) | — | — | — | — | — | — | ✓ |
| Organisation page | — | — ("no organisation") | ✓ (agency) | ✓ (read-only status) | ✓ | ✓ | — |
| Delete account | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Admin anything | never in this app | | | | | | |

Not public sign-up paths (never offered on the purpose screen): Maintenance provider (admin invitation), Aqarati Broker (Super Admin + Senior approval).

## Admin Web Console (`admin_web/`)

| Permission | Reviewer | Senior Reviewer | Super Admin | Auditor | Basis |
|---|---|---|---|---|---|
| View queue and submissions, dashboard, accounts list, moderation list | ✓ | ✓ | ✓ | ✓ | §47 |
| Open documents (streamed, watermarked, audited) | ✓ | ✓ | ✓ | — | §47 |
| Claim / approve / reject / request resubmission | ✓ | ✓ | ✓ | — | §47 |
| Final (second) approval: developers, Aqarati Brokers | — | ✓ (not the first approver) | ✓ (not the first approver) | — | §47, §83 |
| Override / reopen | — | ✓ | ✓ | — | §47 (permission modelled; no reopen screen yet) |
| Suspend / reinstate (step-up) | — | ✓ | ✓ | — | §47 |
| Invite maintenance providers | — | — | ✓ | — | §47 diagram |
| Create Aqarati Broker grants | — | — | ✓ | — | §47 (no screen: programme pending) |
| Manage admin users | — | — | ✓ | — | §47 |
| View audit log | — | ✓ | ✓ | ✓ | §89 |
| Moderate reviews | ✓ | ✓ | ✓ | — | DERIVED |
| Manage ad banners | — | ✓ | ✓ | — | DERIVED |
| Act on own / related account | never | never | never | never | §50.3 |
