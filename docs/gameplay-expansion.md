# Tactical boards, chocolate garden and guardian arenas

This document records the first eight-level expansion. The subsequent [mastery and delivery update](mastery-delivery-and-hints.md) extends each chapter to 19 levels.

## Campaign content

The four playable chapters now contain 17 levels each, for 68 campaign levels. Existing levels 1–15 are preserved. Level 16 offers a new challenge and level 17 ends each chapter with its guardian in a different arena. The original guardian encounters at level 15 remain playable.

| Level | Playing idea | Board | Starting moves |
|---|---|---|---:|
| Rat 16 | A compact treasury: open the two corner locks and collect both tribute colors | 5 × 5, four colors | 8 |
| Ox 16 | Aim Lightning between the side locks, then work around gold frames | 5 × 5, four colors | 8 |
| Tiger 16 | Choose how to spend a Lucky Five while thawing the small snowfield | 5 × 5, four colors | 8 |
| Rabbit 16 | Clear a blossom garden while containing a small chocolate pocket | 7 × 7, five colors | 14 |
| Rat 17 | Collect rotating tribute across the bridges of a divided treasury | 7 × 7, four colors | 13 |
| Ox 17 | Crack gold frames and route specials through three connected lanes | 9 × 9, five colors | 26 |
| Tiger 17 | Build cascades around an empty courtyard while watching the frozen row | 9 × 9, five colors | 21 |
| Rabbit 17 | Clear blossom paths and vaults while fighting the Rabbit's column raids | 9 × 9, five colors | 23 |

These boards use existing matching, falling, protection, collection and guardian rules. Initial normal tiles remain random, so the compact boards reward tactical choices without requiring a fixed solution. Each rematch keeps its guardian's existing weaknesses and attack cadence; its arena changes the routes available to the player.

Move limits and collection goals were tuned from 200-game sensible-bot samples. Second- and third-star thresholds use the tuning runs' 40th and 80th percentiles of winning scores, rounded to the nearest 100 points. See [gameplay-expansion-balance.md](gameplay-expansion-balance.md) for the final validation sample. Guardian rematches won 38–46% of sensible games. Rat 16 (78%) and the first chocolate garden (68%) provide more forgiving breaks around those rematches; other compact boards won 44–48%. These are sampled bot results, without tools, continues or timers, rather than predicted player win rates.

## Chocolate pressure

Rabbit 16 starts with one chocolate tile between two locks, above an Enhanced tile that can help open the garden. There are 19 blossom layers and a lantern collection goal. There is no separate chocolate objective, and clearing chocolate does not count as opening a lock.

An adjacent clear removes chocolate. While a source remains, the between-turn world step can turn one adjacent unprotected normal tile into chocolate. It does not overwrite frozen tiles, gold frames, power-ups, ingredients or locks. Spreading preserves the blossom underneath the converted tile; clearing chocolate from that cell removes one blossom layer through the existing positional-goal logic. Removing the last source stops further growth. Spread consumes the same paid-turn token as guardian raids: Hammer, Ruyi Swap, Shuffle, setup and repeated turn callbacks do not spread chocolate. A continue applies the deferred paid move once; declining or restarting discards it.

The first briefing at Rabbit 16 teaches chocolate. Reaching that level also unlocks its handbook rule. The small initial pocket gives players a chance to contain it before it restricts the board.

## Blast preview

With **Power-up blast previews** enabled in Settings, drag a power-up toward a neighboring movable tile and keep the finger on that neighbor to inspect the activating swap. Release there to commit through the normal move handler. Moving back to the original tile or ending elsewhere cancels the preview. Ordinary matching swaps retain their existing input path.

The preview outlines cells touched directly by the power-up or pairing. Armor and ice can absorb a hit, and chain reactions or falling matches can reach beyond the outline. It is a planning aid for the direct footprint rather than a forecast of every eventual clear.

Preview calculations use virtual post-swap positions and do not mutate the live board, consume moves, advance a guardian or spend tools. Pause, interruption, resolution, tool selection, restart and result transitions discard a pending preview. Outlines are static and work with reduced effects. Enhanced tiles receive a preview only when the virtual swap actually matches them; moving an Enhanced tile without activating it follows the existing swap path.

## Existing progress

The normal level-discovery and record-reconciliation paths load the appended files. Players who finished level 15 receive access to level 16; level 17 opens after level 16 is completed. Saved completions and stars are preserved, and initialization does not duplicate the new records.

Chapter star-chest thresholds follow the chapter's level count, increasing to 17, 34 and 51 stars. Already claimed chests stay claimed through their existing per-chapter keys.

## Verification

- Structural validation of the eight new JSON files checks rectangular layouts, matching overlay dimensions, protection on playable cells, rising star thresholds and lock goals within the authored lock count.
- `ProgressionTests` covers compact-board dimensions and colors, new arena layouts, the retained level-15 guardians, the new chapter finales and completed-save expansion to level 16 without losing old stars or duplicating records.
- `ExpansionContentTests` covers one-cell chocolate spread, protected and non-normal targets, piece identity, adjacent clearing, blossom-layer accounting, lack of lock credit, the Rabbit 16 teaching/unlock boundary, matching colors for preplaced Enhanced tiles, all three localization tables and preservation of already claimed chests when thresholds grow.
- `FestivalFeaturesTests` compares all five combination footprints with the live resolver in both directions and at board edges, and checks repeated previews preserve identities, protection, goals and possible swaps.
- `BlastPreviewInteractionTests` exercises the real Scene coordinate handlers, native sprites and clipped outlines: cancellation, release once, stale identities, pause/restart, tool modes, ordinary swaps and the disabled preference.
- `ChocolateTurnCadenceTests` covers paid turns, free tools, duplicate callbacks, coin/ad continues, deadline crossings, decline, restart and exhausted offers.
- `ReleaseRegressionTests` now reshuffles all 68 levels repeatedly, verifies preference persistence and captures the new briefings at small-phone/tablet sizes with large and maximum accessibility text. Visual review also prompted a scalable goal-grid minimum and a nonwrapping guardian-health badge.

The complete simulator suite passed 132 tests with zero failures; the opt-in balance-report test was the only skipped test. A final 14-test acceptance run passed, including the explicit report (200 sensible and 100 random games per new level, 2,400 games total), new-content checks and post-layout-fix briefing snapshots. Native preview, Settings and corrected guardian-goal screenshots have been visually inspected at phone/tablet and accessibility sizes. Two additional native layout tests passed after the final star-icon sizing adjustment; maximum-size score numerals and guardian health were visually confirmed intact. The final unsigned Release build for generic iOS passed (`CODE_SIGNING_ALLOWED=NO`).
