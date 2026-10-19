# Star guidance and combo recipes

The next release adds presentation improvements around the existing star system and power-up combinations.

## Star goals

The level briefing now says that completing the level earns one star. The two- and three-star score thresholds are still shown, with no changes to star calculation or level data.

After a one- or two-star win, a card shows the next score threshold and the points shortfall for **this attempt**. It reads the final victory receipt after the Festival Finale finishes. Saved best stars, scores, rewards and chest progress are independent of this card.

The card is omitted for three-star wins, debug demos, a missing or mismatched level, and invalid or inconsistent score data. Score differences use nonnegative values and are checked before subtraction.

## Combo recipes

After Power-up Combos unlocks, the rule handbook offers a collapsible guide to the five existing pairings. Each recipe shows the same tiles and enhanced overlay as the board, plus its existing title and effect description. The guide explains that neighboring power-ups can be swapped in either order and a regular swap uses one move.

The guide is a static reference. Its text wraps vertically, the pair artwork is decorative for VoiceOver, and recipe text is grouped for reading. Opening the guide does not run a demo or alter the paused board.

All new copy is localized in English, Simplified Chinese, and Traditional Chinese.

## Verification

- Score-boundary tests cover one/two/three stars, prior best scores, malformed receipts and thresholds, debug demos, and the largest valid score.
- The existing one-star replay regression checks the new target while retaining three saved stars, chapter progress, and inventory.
- Native SwiftUI snapshots cover the new briefing and feedback card, expanded combo recipes, the bottom of scrollable content, all three languages, a 320-point phone with accessibility text, and an iPad-sized layout.

Verification run on an isolated iPhone 17 simulator with iOS 26.5: **96 tests passed, 0 failed**. The optional balance-report generation test was skipped as expected. The new guidance screenshots and existing replay result screenshots were inspected; text wraps, the final recipe is reachable, and the victory actions remain reachable at accessibility text sizes. All three localization tables and the Xcode project pass `plutil -lint`; `git diff --check` passes.

The unsigned Release build for the generic iOS destination (iPhone/iPad) also passed with `CODE_SIGNING_ALLOWED=NO`. Existing SpriteKit compiler warnings remain in untouched scene code. The temporary test simulator was removed after verification.
