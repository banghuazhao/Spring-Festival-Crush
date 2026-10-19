# Guardian and pause recaps

Continue offers now show the guardian's current and maximum health alongside the unfinished level goals. A surviving guardian is described as almost beaten only at one quarter of its maximum health or below. Higher health uses neutral wording; zero health says the guardian is defeated while still listing any unfinished goals.

The pause overlay shows the same remaining goals and guardian status, plus moves remaining and time remaining for timed levels. Completed goals are omitted from the list. The summary is hidden when there is no loaded level.

Both overlays use a shared read-only SwiftUI recap. It reads the current attempt without changing the board, goals, timer, inventory, continue pricing, rewarded-ad callbacks, or pause/resume flow. Counts wrap into vertical rows at accessibility text sizes. Copy is available in English, Simplified Chinese, and Traditional Chinese.

At accessibility text sizes the continue purchase stacks its benefit and price so the price stays on one line. The continue screen also opts into a vertically arranged rewarded-ad label with a rounded rectangular shape; other rewarded-ad buttons keep their existing layout. Snapshot capture waits for the continue entrance to finish.

## Verification

- Guardian presentation tests cover full/high health, the quarter-health boundary, defeated guardians, tiny maximum health values, invalid inputs, clamping, and integer extremes.
- Native pause and continue snapshots cover full-health, nearly defeated, defeated, and absent guardians; timed and untimed attempts; all three languages; small phones and an iPad-sized layout; and accessibility text sizes.
- Snapshot regressions check that rendering does not change the board, goals, moves, time, guardian health, inventory, or pending continue offer. The bottom of each overlay is also captured to check access to its controls.

Final verification on an isolated iPhone 17 simulator with iOS 26.5: **101 tests passed, 0 failed**, with the optional balance-report generation test skipped as expected. Final screenshots were inspected in all three languages, including full/low/zero guardian health and accessible continue prices, rewarded-ad labels, and pause controls. Localization tables and the Xcode project pass `plutil -lint`; `git diff --check` passes.

The final unsigned Release build for generic iOS (iPhone/iPad) also passed with `CODE_SIGNING_ALLOWED=NO`. Existing warnings remain in untouched SpriteKit and test code. The temporary simulator was removed after verification.
