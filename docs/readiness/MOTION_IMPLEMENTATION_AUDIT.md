# Motion implementation audit

Updated 2026-10-21. The app already had one shared motion system (`lib/core/aq/aq_tokens.dart` → `AQMotion`, `lib/core/aq/aq_scene.dart` → `AQRoute`, `AQStepSwitcher`, `showAQSheet`, `AQThemeTransition`; `lib/core/aq/aq_primitives.dart` → `AQPressable`). **No second motion framework was added.** Every new screen uses those primitives. Earlier detail lives in `docs/motion/`.

## Tokens (source of truth, unchanged)

| Token | Value | Brief target |
|---|---|---|
| `tapDown` / `tapUp` | 100 / 160 ms, scale 0.98–0.985 | 90–160 ms ✓ |
| `icon` | 180 ms | 140–220 ms ✓ |
| `state` | 220 ms | content reveal 180–260 ms ✓ |
| `page` push / `standard` pop | 300 / 260 ms, 20 px travel, RTL-mirrored | 240–320 ms ✓ |
| `sheet` / `sheetReverse` | 320 / 240 ms | 260–360 ms ✓ |
| `formStep` | 240 ms, 14 px travel | 220–300 ms ✓ |
| `theme` / `themeReduced` | 340 / 100 ms | 280–420 ms ✓ |

## Sequences used by the new screens

| ID | Where | Trigger | Start → end | Duration / easing | Reverse | RTL | Reduced motion | Evidence |
|---|---|---|---|---|---|---|---|---|
| MOT-01 route | all 34 new routes (`product_routes.dart`) | push / pop | `AQRoute.forward` fade + 20 px slide from the forward side | 300 ms easeOutCubic / 260 ms | pop reverses | travel mirrors | plain fade | `motion_test.dart` (existing family), new routes use the same builder |
| MOT-01 sheet-page | `/help/:id`, `/reviews/write`, `/reviews/report`, `/reviews/:id/edit` | push | `AQRoute.sheet` rise 6 % + fade | 380 / 260 ms emphasized | drops back | n/a (vertical) | fade | same |
| MOT-01 hero | `/listings/:id/submitted`, `/session-expired` | push | `AQRoute.hero` scale 0.96 → 1 + fade | 480 / 260 ms | reverse | n/a | fade | same |
| MOT-02 sheets | `?` help, confirmations (`aqConfirm`), leave-wizard, choice sheets, contact sheets, email change | open / dismiss | `showAQSheet` rise + 40 % backdrop | 320 / 240 ms | drag, backdrop, Cancel | n/a | Flutter default sheet animation honours platform | flows tests open/close sheets |
| MOT-03 buttons | every new CTA | press | `AQPressable` scale; loading spinner only while the repository call runs | 100 / 160 ms | release | n/a | no scale | `completion_flows_test` (submit disabled while running) |
| MOT-04 theme | Settings → Light / Dark / Same as device | tap | palette interpolation through `AQThemeTransition`; route, scroll, form values untouched | 340 ms easeInOutCubic | — | — | 100 ms | existing `motion_test.dart`; Settings uses the same provider |
| MOT-05 wizard | listing wizard (6 steps), provider invitation (4 steps), review composer (compose ↔ preview) | Continue / Back | `AQStepSwitcher` directional slide + fade, progress bar animates | 240 ms | Back slides the other way | mirrors | instant | flows tests walk all steps |
| MOT-05 validation | wizard, composer, report, profile edit | failed Continue | inline error under the field (`AQAnimatedSize` fade/size), banner; no page shake | 180 ms | errors clear on fix | — | instant | flows tests |
| MOT-06 loading | every new list / detail | provider loading | `AQSkeletonRows` sized to the final rows | — | crossfade by rebuild | — | — | matrix tests |
| Star picker | review composer | tap star | scale 0.9 → 1 on selected stars | 180 ms | — | — | static | composer flow test |
| Timeline dots | listing / engagement / e-Broker steps | state change | colour + fill via `AnimatedContainer` | 220 ms | — | follows layout direction | instant | matrix |
| Admin console | page change, dialogs | navigation | 240 ms fade (desktop: no travel); Material dialogs | 240 / 160 ms | — | — | instant (`AdminMotion.reduced`) | admin UI tests |

## Not done / not verified

- No device-level reduced-motion check was performed (only the `MediaQuery.disableAnimations` code paths, already covered by the existing motion tests).
- Screen-reader announcement of motion changes was not tested with a real screen reader.
- The admin console uses Material dialogs (not the AQ sheet), which is appropriate for desktop.
