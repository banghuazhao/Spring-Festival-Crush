# Progression and comfort pass (items 4–6)

## Implemented

- Victory rewards: authoritative stars, score, coins and newly unlocked level are captured before presentation. Short sequential star/reward reveals can be skipped safely with Continue to Map or Play Next. Returning to the map consumes a one-shot receipt, scrolls to the destination and reveals its gold trail/node. Replaying a completed level does not claim an existing unlock as new.
- Themed Settings: festival panels, independent music/effects volume, haptics, screen shake, reduced effects and idle hints. Preferences persist and update shared UI immediately. System Reduce Motion always takes precedence; the in-game preference also reduces board, transition and ambient effects. Existing audio assets use bounded cached voices, with landing/falling throttling.
- Idle hints: two quiet tile outlines after seven seconds of eligible inactivity, once per idle interval. They do not consume moves or tools and are canceled on interaction, pause, resolution, tutorial hints and tool use. Resuming starts a fresh delay.
- Accessibility: scrollable reward/settings layouts, Dynamic Type adjustments, contrast-aware controls, and reduced-effects alternatives. Decorative content is reduced at accessibility text sizes to keep actionable controls readable.

## Verification

- All 23 XCTest regression tests passed on an isolated iPhone 17 / iOS 26.5 simulator. Coverage includes reward/unlock accounting, one-shot map receipts, replay behavior, persisted comfort preferences, hint eligibility/cancellation, real SpriteKit animation behavior and hosted SwiftUI layouts.
- Debug simulator and unsigned generic-device Release builds passed. `git diff --check` passed.
- Reviewed rendered Settings and Victory layouts at 375 × 812, including accessibility text sizes; also reviewed dark landscape Settings and the unlocked trail component. Snapshot feedback led to a simpler accessibility header/reward row and improved navigation contrast.
- Final snapshots were exported to `/tmp/spring-progress-final-layouts` (temporary QA artifacts, not bundled).
- The Mac locked before hands-on testing of this batch. Interactive pause/settings and the complete victory-to-map transition, physical-device audio/haptic tuning, and the full iPad layout matrix remain release checks. Automated hosted layouts and model/scene regressions passed; they do not replace those manual checks.
- No new media assets, production ad requests, signing changes or store submission changes were made.

Items 1–3 were committed separately as `6c12f07`; see `game-feel-feedback.md` for their implementation and hands-on verification.
