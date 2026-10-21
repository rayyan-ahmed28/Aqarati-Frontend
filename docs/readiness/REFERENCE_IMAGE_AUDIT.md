# Reference image audit (`Following.zip`, 76 boards)

Updated 2026-10-21. Reference boards are visual guidance only. Four boards were opened and inspected visually in this pass; the remaining 72 were classified from the index file names (`07_REFERENCE_IMAGE_INDEX.csv`) and **were not individually inspected**. No reference image was copied into production assets.

## Boards inspected

| Board | Class | Used | Rejected (and why) |
|---|---|---|---|
| AQARATI Account & Settings Flow (ACC-01) | screen-specific + motion storyboard | Account tab structure (profile header with avatar, name, email, verified chip; grouped rows; sign out; delete), Settings grouping (appearance incl. "system default", language, notifications, privacy, security), Privacy & Legal list, Security & Sessions list, account-deletion warning → typed confirm → result (already built), motion notes (tab tap scale, 300 ms slide, 400 ms theme) | Fifth bottom tab ("Saved") — nav stays Home · Explore · Activity · Account; "Complete your profile 80 %" meter (no completeness rule in source); date of birth, gender, "About you" fields (not in the PATCH /me contract); UAE flag / +971 numbers (Oman, +968 only); "Active sessions (2)" list and Two-factor toggle for customers (no device list contract; customer 2FA not defined); cookie policy (not supplied); "Account deleted, thank you" as a guaranteed outcome (demo states nothing was deleted on a server); mock person name and photo |
| AQARATI Engagement & Reviews UI Board-4 (ENG-03…REV-03) | state board | Declined / expired / ineligible / unavailable outcome cards, engagement list with status, progress timeline, cancel confirmation with reason optional (implemented without a reason field), waiting-for-confirmation state, review composer (stars + text), my reviews with edit, report flow (confirm → reason → submitted), review empty / loading / error states | Blue primary buttons (off-brand); "Mark as completed" by the client and "Reschedule engagement" (not in the engagement model); "Add to Calendar" (no calendar integration); "Delete review" (not in the source rules); "Was this review helpful?" (not in source); fixed report reason radio list (no published report codes, free text used instead); ratings breakdown percentages and mock names |
| AQARATI Members & Permissions Showcase (ACC-04) | screen-specific — **rejected for implementation** | Only the Organisation section layout idea (company card + rows) informed the Organisation page | The whole members / roles / permissions / invite-member / member activity flow: organisation staff members are REMOVED from the MVP (single owner, architecture §5.3). The Organisation page says so. Also rejected "Billing & Plans" (no billing in the app) |
| AQARATI Notification Inbox Showcase (NOT-01) | screen-specific + state board | Unread dot + bold title, grouping by time, empty / loading / error / retry states, tap → destination screen flow, Arabic RTL mirror | Messages / "New message" / Reply (no in-app messaging); "Property matches", "Price drop" alerts and Promotions (not defined events); push / email / category toggles (optional categories not defined, push not connected — shown honestly in Notification settings); archive and swipe-to-delete (no archive contract); "Add to Calendar" |

## Remaining boards, classified by title (not opened)

| Group (count) | Expected class | Handling |
|---|---|---|
| Engagement / review flow boards, storyboards, design systems (≈ 45: "Engagement…", "ENG-02…", "Review Flow UI Spec Sheet-11", "Mobile Engagement…") | state boards / motion storyboards / mixed collages | Treated as variations of ENG/REV board 4; same accept / reject rules applied |
| Account settings showcases (5: "Account Settings Flow", "…Showcase", "Profile & Settings Showcase", "Luxury Account Settings UI Showcase", "Appearance & Language Settings Board") | screen-specific | Same rules as ACC-01 |
| "Organisation Profile App Flow" | screen-specific | Organisation page (single owner, no members) |
| "Notification Deep Link Flow Board", "Notification States Board" | state boards | Same rules as NOT-01 |
| "Warm Mobile Privacy Design Showcase" | screen-specific | Privacy & legal page structure only; no invented legal copy |
| Product / UX presentation boards, journey maps, storyboard collages (≈ 15) | moodboards / mixed collages — unsafe as specs | Not used as feature sources |
| "Professional Marketplace UX Flow Board-5" | mixed | Marketplace is out of MVP scope — rejected |

## Rules applied

- No mock names, ratings, prices, IDs, addresses or transaction data from boards entered the code. Demo data stays clearly fictional and labelled "(demo)".
- Brand colours come from the repository tokens, not from the boards (boards drift between mocha and blue).
- Customer bottom navigation is unchanged: Home · Explore · Activity · Account.
