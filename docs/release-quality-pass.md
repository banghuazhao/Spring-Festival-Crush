# Release quality pass — 2026-09-12

## Gameplay fixes

- **Preserve board progress when shuffling.** Manual and automatic reshuffles rearrange existing pieces instead of rebuilding from level JSON. Cleared blockers stay cleared; frozen pieces and ingredients stay in place; specials and objective progress are retained. The search is bounded and restores the original board on failure, without charging the player.
- **Free dead-board recovery.** After a turn with no possible swaps, attempt a free reshuffle. If the board cannot safely be rearranged, explain that a Hammer can open it instead of silently leaving the player stuck.
- **Race-safe level lifecycle.** Attempt identifiers invalidate old async setup, match, shuffle and bonus work after Exit or a new level. Repeated Next/Retry taps cannot start overlapping attempts.
- **Fair timer resolution.** A move in flight settles before deciding a timeout. Win-bonus scoring enters a distinct finishing state immediately so the clock cannot deduct a life or trigger a second result. Countdown stops at zero.
- **Interruption handling.** Scene and timer pause when inactive; returning from an interruption requires Resume. Reward ads also suspend gameplay, including an extra-life reward that starts a retry before the ad closes.

## UI and ads

- Keep the tools in one row, with no move charge for Shuffle.
- Show a short status message for free reshuffles and a bonus-counting banner while finishing.
- Keep the refill sheet's close/return action anchored at the bottom; use a large sheet for accessibility text sizes.
- Hide underlying gameplay controls from interaction/accessibility while modal UI is active.
- Respect Reduce Motion in the result entrance, crown/stars, failure badge and confetti.
- Route tools, coins and lives through the shared true-rewarded-ad manager. Grant rewards only on the earned-reward callback; expose loading, no-fill and retry states.
- Prevent app-open ads from interrupting an active game or stacking onto a rewarded ad when the app returns to the foreground.

## Automated verification

Added `SpringFestivalCrushTests` to the shared Xcode scheme with 11 regression tests:

1. Shuffle preserves live piece identity, specials, blockers and frozen positions.
2. Impossible shuffle restores the board.
3. Double-tapped Shuffle spends one charge and zero moves.
4. Unavailable shuffle keeps the charge.
5. Exit during setup cannot restart the game.
6. An old Hammer cascade cannot modify a new attempt.
7. Timer cannot lose during win bonuses or award a win twice.
8. Timeout waits for an in-flight move.
9. Tool inventory survives attempt resets.
10. Repeated Next Level taps advance only once.
11. Timeout stops at zero and deducts only one life.

Run using `xcodebuild test -project SpringFestivalCrush.xcodeproj -scheme SpringFestivalCrush -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO`. Prefer an isolated test simulator. Tests restore the preference keys they modify.

The 11 tests pass on iPhone 17 / iOS 26.5. The unsigned Release iPhone/iPad build also passes. Production ad configuration is preserved in the existing Git-ignored Release.xcconfig; no live ads were requested or clicked.

## Remaining release checks

The Mac lock screen blocked this pass's manual simulator review. Before shipping, verify small-phone/iPad layouts, accessibility text, background → Resume, Settings → Pause, expired/no-fill ads, early ad dismissal, and all three chapter finales on-device. Version/build numbers, signing, App Store submission and commits were not changed by this pass.
