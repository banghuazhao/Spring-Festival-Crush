# Power-up mastery, gift deliveries and goal-aware hints

This document records the expansion to 19 levels per chapter. The subsequent [capstone update](capstone-levels.md) extends each chapter to 20 levels.

## Campaign content

Each playable chapter gains levels 18 and 19, bringing the campaign to 76 levels: 19 each for Rat, Ox, Tiger and Rabbit. Existing levels 1–17 stay unchanged, including guardian encounters at levels 15 and 17. The appended challenges use existing power activation, protection, falling, collection and blossom rules, without a new timer or guardian attack.

| Level | Playing idea | Board | Starting moves |
|---|---|---|---:|
| Rat 18 | Trigger Lightning and Lucky Five powers while opening four double locks | 7 × 7, four colors | 18 |
| Ox 18 | Activate all three power types around double locks and gold frames | 7 × 7, five colors | 26 |
| Tiger 18 | Use a Lucky Five and thaw the field to set up Lightning and Blast Tile activations | 7 × 7, five colors | 26 |
| Rabbit 18 | Activate all three powers while clearing the blossom garden | 7 × 7, five colors | 20 |
| Rat 19 | Learn two open gift routes while collecting red envelopes | 7 × 7, four colors | 10 |
| Ox 19 | Keep both gift lanes moving while clearing side locks and gold frames | 7 × 7, five colors | 14 |
| Tiger 19 | Deliver gifts from the top of a snowfield with ice beside their routes | 7 × 7, five colors | 16 |
| Rabbit 19 | Clear beneath gifts to advance them through a blossom garden | 7 × 7, five colors | 16 |

Move limits were tuned with 200 sensible and 100 random games per board. Second- and third-star thresholds use the tuning sample's 40th and 80th percentiles of winning scores, rounded to the nearest 100 points; first-star values are unchanged. The same layouts and goals are retained throughout tuning. See [mastery-delivery-balance.md](mastery-delivery-balance.md) for the latest report; final verification results are recorded below.

## Mastery goals

Activation goals count actual firings of Lightning, Lucky Five and Blast Tiles. Each initiating power in a pairing counts, as do converted powers and powers reached by chain reactions. Creating a power without activating it does not finish its activation goal. These are activation missions rather than requirements to make a particular two-power pairing.

Every requested power type starts on its mastery board. Goals can exceed those initial pieces, encouraging players to create more powers or combine the starting pieces efficiently. Boards with a preplaced Blast Tile include firecrackers in their color palette, matching the existing authored Enhanced tile type.

The first activation mission is Rat 18. Its briefing teaches the goal counters, and the rule remains available in the handbook as later chapters combine activation targets with locks, gold frames, ice and blossoms.

## Gift routes

Every delivery board starts with exactly two gifts, has a complete playable bottom row and provides an open, unprotected vertical route beneath each gift. Side obstacles give later boards variety without blocking the first route before play begins. This batch uses no chocolate on delivery boards.

Clearing beneath a gift lets gravity move it toward the board's bottom row. A gift arriving at a bottom-row exit is collected. The existing rules also allow a special blast or Hammer to collect a gift directly; players can choose between opening a route and setting up a direct clear. Falling can move a gift into a different column, so exit markers cover every playable bottom-row cell. Exit collection now settles the board again before refilling: stacked gifts can leave in the same resolution, and a delivered gift no longer leaves an empty bottom cell until the next move. The settling loop stops after the finite set of existing gifts and checks the attempt identity after each animation; restarting cannot continue the old delivery loop. The headless solver follows the same sequence.

Rat 19 introduces gift delivery in its briefing and unlocks the handbook entry. Later delivery levels add side locks, gold frames, ice or blossoms while retaining two starting gifts and the same collection rules.

## Goal-aware hints

The gentle-hint setting keeps its existing inactivity delay and cancellation rules. Move selection now considers unfinished objectives, helping point toward useful powers, collection colors, blockers or positional goals. The outline remains a suggestion based on the visible board; it does not guarantee a win or forecast random falling tiles.

Showing a hint does not perform a swap, spend a move, use a tool or change progress. Interaction, pause, tools, tutorial guidance and board resolution continue to suppress idle hints through the existing eligibility path. Ranking reads a virtual post-swap snapshot and considers direct collection, blossoms, locks, activation sources, useful paths below gifts and known guardian weaknesses. Goal credit is capped by the amount remaining; completed goals do not dominate selection. Equal or zero benefits retain deterministic coordinate ordering. The Settings explanation now describes the goal-aware behavior in all three languages.

## Existing progress and chests

The existing reconciliation path appends the new records. A player who completed level 17 can play level 18 immediately; level 19 stays locked until level 18 is completed. Players arriving from an older 15-level save still open level 16 first. Repeated initialization does not duplicate records or reset saved stars.

Chapter chest thresholds follow the new count: 19, 38 and 57 stars. Already claimed chest indices remain claimed, including a third chest opened before the expansion, and cannot award their reward a second time.

## Verification

- Nine `GoalAwareHintTests` check unfinished versus completed goals, legal fallback, live identities, protected pieces, activation/gift/guardian benefits and repeated side-effect-free evaluation.
- Six `MasteryDeliveryRulesTests` cover one-shot bottom collection, stacked deliveries and refill, direct Lightning/Hammer collection, no duplicate reward, restart during delivery and preserved gifts during reshuffling.
- Seven `DeliveryTeachingTests` cover curriculum boundaries, positive activation goals, absolute bottom-row exits, marker lifetime/bounds, actual boss metadata and all three localization tables.
- `MasteryDeliveryContentTests` validates the eight new boards, gift routes, goal supplies, overlays and retained chest claims. `ProgressionTests` covers both 15-level and 17-level saved chapters expanding to 19 records.
- Native `ReleaseRegressionTests` snapshots cover mission briefings, activation/gift labels and attempt recaps at small-phone/tablet sizes, English and both Chinese translations, and accessibility text through the maximum size.

The tuned targeted run passed 55 tests. The complete simulator suite then passed **160 tests with zero failures**; its only skipped test was the opt-in balance report. The explicit final report also passed: **200 sensible and 100 random games per new level, 2,400 games total**. In that validation sample, mastery missions won 30–58% of sensible games and delivery missions won 58–72%. The first gift mission is intentionally more forgiving. These samples exclude tools, continues and timers and are not forecasts of player win rates.

Native phone/tablet exit screenshots and mission briefings/recaps were visually inspected in English, Simplified Chinese and Traditional Chinese, including maximum accessibility text. Project/string validation, `git diff --check`, and the final unsigned Release build pass.
