# Mixed-goal chapter capstones

Each playable chapter gains a level 20 that combines the gift-delivery and power-activation rules introduced in levels 18 and 19. The campaign now contains 80 levels, 20 each for Rat, Ox, Tiger and Rabbit. Existing levels 1–19 are preserved, including both guardian encounters at levels 15 and 17.

## Boards

| Level | Playing idea | Goals | Starting moves |
|---|---|---|---:|
| Rat 20 | Open gift lanes while setting up Lightning and Lucky Five activations | 2 gifts, 6 Lightning activations, 2 Lucky Five activations | 20 |
| Ox 20 | Balance deliveries with side locks and powers around gold frames | 2 gifts, 4 locks, 4 Lightning activations, 5 Blast Tile activations | 24 |
| Tiger 20 | Keep gift lanes moving while building powers through the snowfield | 2 gifts, 5 Lightning activations, 5 Blast Tile activations | 28 |
| Rabbit 20 | Use powers to tend blossom paths and advance both gifts | 2 gifts, 19 blossom layers, 4 Lightning activations, 5 Blast Tile activations | 24 |

All four boards are 7 × 7. Rat uses four colors; the other chapters use five. Every requested power type starts on its board, and later capstones also include a Lucky Five that can help set up a stronger combination. Preplaced Blast Tiles use the firecracker color, which is included in their palettes.

Solver tuning used 200 sensible and 100 random games per board. Star thresholds use the tuning samples' 40th and 80th percentiles of winning scores, rounded to the nearest 100 points. Tiger received four additional moves and a fresh sample before its thresholds were set. First-star values remain 1,200 points. The independent [final balance sample](capstone-balance.md) records the completed values and verification results.

## Existing rules together

Every capstone starts with two gifts above open, unprotected vertical lanes and a complete playable bottom row. Side obstacles leave those starting routes open. Gifts can fall to any playable bottom-row exit, and the existing rules also allow a special blast or Hammer to collect a gift directly.

Power goals count actual activations, including initiating powers in pairings, converted powers and powers reached by chain reactions. Creating a power without firing it does not finish its activation goal. The combination of objectives encourages players to consider which power clears a delivery route while also advancing the activation counters.

Completing one part does not waive the other. A board still needs its gifts and every requested activation, plus any lock or blossom goals. These capstones add no timer, guardian attack, chocolate spread rule or new board-resolution mechanic.

## Saved progress and chests

Players who finished level 19 receive access to level 20 through the existing record reconciliation. Completed levels and saved stars remain intact, and repeated initialization does not duplicate the capstone records. Older 15- or 17-level saves still unlock only their first newly added level.

Chapter chest thresholds follow the new count: 20, 40 and 60 stars. A previously claimed chest stays opened even below its new threshold and cannot award another reward after the expansion.

## Verification

- `CapstoneContentTests` checks mixed goals, starting power availability, gift counts, complete bottom exits, open starting routes, protection placement, matching Blast Tile palettes and the requirement to finish delivery and activation progress together.
- `ProgressionTests` checks all 20 levels per chapter, retained guardian encounters and save reconciliation from 15, 17 and 19 levels. The 19-level migration test also preserves real saved chest claims and refuses duplicate rewards.
- The initial authoring pass structurally validates the JSON layouts, overlays, lock counts, gift routes and rising star thresholds.

The targeted run passed 48 tests. The complete simulator suite then passed **180 tests with zero failures**, including winnability and repeated reshuffle checks across all 80 levels. Its only skipped test was the opt-in balance report; the separate final report passed with **1,200 games**. Sensible-play win rates were Rat 63%, Ox 52%, Tiger 43% and Rabbit 50%. Tools, boosters, continues and timers are excluded, and these samples do not predict player win rates.

Native board scouts and corrected retry screens were inspected at phone/tablet sizes in English, Simplified Chinese and Traditional Chinese, including maximum accessibility text. Project/translation validation and whitespace checks pass. The final unsigned Release build passes with code signing disabled.
