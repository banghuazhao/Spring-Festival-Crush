# Tool toolbar and rewarded refills

- One row: Shuffle and Hammer, each with an icon, remaining count and a 44-point refill button. No Shuffle text or move cost.
- New inventory starts with 3 Shuffle charges and 0 Hammer charges. Counts persist across attempts and launches using UserDefaults. Purchased hammers also join this inventory; extra moves remain per-attempt.
- Each Shuffle spends exactly one charge and no moves. Board-resolution guards prevent repeated taps or swaps from overlapping tool actions.
- A refill opens an opt-in sheet. A completed rewarded ad adds one charge; closing early or a failed presentation adds none. The scene and countdown remain paused through the sheet and ad. Returning to the game never automatically uses the reward.

## Ad configuration

Debug builds use Google's iOS rewarded test unit `ca-app-pub-3940256099942544/1712485313`. Release builds read the `RewardedAdUnitID` build setting through Info.plist, configured in `SpringFestivalCrush/Config/Release.xcconfig` as `ca-app-pub-4766086782456413/2156787796`. This must remain an AdMob **Rewarded** unit; an Interstitial ID is not compatible. With no ID or no fill, refills display an unavailable message and do not grant rewards. Mac Catalyst does not serve ads.

The new ToolRewardAdManager is isolated from the legacy coin/life interstitial-based helper. Rewards are issued only from GADRewardedAd's earned-reward callback, at most once per presentation.

Reference: [Google's rewarded-ad guide](https://developers.google.com/admob/ios/rewarded).

## Manual QA

Verified on an isolated iPhone 17 / iOS 26.5 simulator: toolbar renders as one row; Shuffle changes 3 → 2 with moves unchanged at 20; empty Hammer opens the opt-in sheet; Google's test ad earns exactly one Hammer (0 → 1); returning to play leaves moves at 20; Pause → Exit returns to the chapter. The app's persisted preferences then contain shuffleCharges = 2 and hammerCharges = 1. Debug build and git diff whitespace checks pass. Early-close, timed-level, large-text and no-fill scenarios remain manual checks below.

1. Start a level, note moves and counts, use Shuffle: count falls by 1, moves do not change.
2. Tap repeatedly during shuffle/cascades: no extra charge or overlapping board mutation.
3. With zero charges, tapping either tool opens its refill sheet. Cancel: no change.
4. Complete a debug test ad: the selected count rises by exactly 1; dismissing early grants none.
5. Leave a timed level's refill sheet open: countdown and board stay paused.
6. Use Hammer: only a valid target consumes a charge. Return to the level map and relaunch: remaining counts persist.
7. Test unavailable ads and large text on a narrow phone: both tools remain on one row; refill actions have accessible names.
