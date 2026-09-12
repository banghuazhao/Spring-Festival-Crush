# Gameplay feedback pass

## Implemented

- Goal collection: one representative tile per changed objective arcs to its actual HUD icon with a short gold trail. Visible counters hold the pending amount until arrival, then pulse and show a checkmark at completion. Accounting is already applied in the model; visual callbacks cannot award progress. Offscreen goals, Reduce Motion, pause and level transitions never leave counters waiting.
- Hammer: a 220 ms wind-up/strike, localized impact ring, sound and haptic cue before the normal clear. Existing charge and no-move-cost rules are unchanged.
- Shuffle: live sprites shrink slightly, follow curved paths and settle within 480 ms. Pieces are temporarily above the board mask so holes don't clip their travel. Frozen pieces, blockers and ingredients remain fixed; Reduced Motion uses a 200 ms fade/reposition.
- Cascades: one audio voice per wave, gently increasing playback rate and volume with a five-tier cap. Brief “Nice!” / “Great!” / “Brilliant!” captions sit above the board. Only deep cascades add a small board shake. These tiers do not change score multipliers or game rules.
- SpriteKit animation tasks run on the main actor. Fixed a pre-existing synchronous keyed `run` call incorrectly treated as awaited; removals now finish before refilling. Special-clear staggering is capped to keep large effects short.

## Verification

- 18 XCTest regressions passed on an isolated iPhone 17 / iOS 26.5 simulator, including real SpriteKit shuffle animations in both motion modes and removal-completion checks.
- Debug simulator and unsigned Release iPhone/iPad builds passed.
- Hands-on QA: Hammer consumed one charge, left 20 moves unchanged, and changed the Rat objective from 15 to 14. Shuffle consumed one charge, retained those moves/goals and settled the board. A second Hammer triggered two- and three-wave cascades; captions appeared above the board and disappeared cleanly.
- Reviewed recorded frames of Hammer wind-up, collection flight/arrival, Shuffle travel and both cascade captions. QA recording: `/tmp/spring-game-feel-qa.mov` (local temporary artifact, not bundled).
- Physical-device audio/haptic tuning and the full screen-size/accessibility matrix remain release checks. No production ads were requested and no image/audio assets were added.
