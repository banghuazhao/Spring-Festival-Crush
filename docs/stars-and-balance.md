# Stars, best scores and Tiger/Ox balance (3.5)

## Stars from solver data

Before 3.5 every win was a three-star win: the median winning score (4,000–22,000, boosted by the Festival Finale) was far above the three-star threshold (1,200–3,000). Stars only recorded whether a level was beaten, and the third star chest opened as soon as a chapter was cleared.

- **★ is any win.** `LevelGoal.stars(forWinningScore:)` gives at least one star to every win, so a low-scoring win never shows zero stars. `GameModel` and the level solver both use it.
- **★★ and ★★★ come from the solver.** For every level, `secondStarScore` is the 40th percentile and `thirdStarScore` the 80th percentile of the sensible bot's winning scores, rounded to the nearest 100. Of the bot's wins, about 60% earn ★★ and 20% earn ★★★. Players who use boosters or continues finish with more moves left, so they get more Finale points.
- `firstStarScore` is unchanged. It only places the first star on the in-game score bar and in the briefing.
- **Existing players keep their stars.** Saved stars are the best ever earned (`max(current, previous)`), so nobody loses stars or chests they already have.
- The report has two new columns, **Win p40 / p80** and **★★ / ★★★ at**, so thresholds can be checked against fresh solver runs. `LevelBalanceTests.testStarThresholdsRise` checks that every level's thresholds rise from ★ to ★★★.

To retune after a level change, run `tools/simulate_levels.sh <Level>` and copy its p40 and p80 into `secondStarScore` and `thirdStarScore`. Levels with very spread-out scores (big Finale chains) move by up to a few thousand points between 200-game runs. For those, `SIM_RUNS=400` gives steadier thresholds.

## Best scores

`BestScoreStore` keeps each level's best winning score in UserDefaults (`bestScore.<Zodiac>.<n>`), like the star chests, so the SwiftData schema is unchanged and no migration is needed.

- The victory screen shows a **NEW BEST!** badge when a replay beats the saved best, and otherwise shows the previous best next to a trophy. A first win is not called a new best.
- The level briefing shows the best score next to the saved stars.
- Levels won before 3.5 have no best score until they are won again.

## Difficulty rebalance

These levels were well outside their difficulty band. Each change only touches moves and goal counts, so boards and rules are unchanged. Win rates are from the sensible bot, 200–400 games per run. "After" gives the range over two or three independent runs; a few points either way is normal run-to-run noise.

| Level | Diff | Band | Before | After |
|---|---:|---|---|---|
| Tiger 2 | 1 | 90% or more | 30 moves, 27 locks: 51% | 33 moves, 24 locks: 96–98% |
| Tiger 4 | 2 | 75–90% | 33 moves, 16 locks: 55% | 34 moves, 14 locks: 86–91% |
| Tiger 5 | 3 | 50–70% | 31 moves, 16 locks: 10% | 33 moves, 12 locks: 66–72% |
| Tiger 6 | 3 | 50–70% | 33 moves, 17 locks: 24% | 33 moves, 15 locks: 60–70% |
| Tiger 7 | 4 | 35–55% | 31 moves, 10 locks: 18% | 33 moves, 9 locks: 45–52% |
| Tiger 8 | 4 | 35–55% | 34 moves, 22 zodiac, 20 firecrackers: 84% | 24 moves, 24 zodiac, 24 firecrackers: 49–50% |
| Tiger 9 | 5 | 20–45% | 34 moves, 17 locks: 13% | 34 moves, 16 locks: 35–40% |
| Ox 7 | 3 | 50–70% | 26 moves: 39% | 28 moves: 50–51% |
| Ox 11 | 4 | 35–55% | 29 moves, 12 locks: 24% | 29 moves, 11 locks: 46–48% |
| Ox 14 | 5 | 20–45% | 31 moves, 12 locks: 12% | 32 moves, 10 locks: 41–46% |
| Rabbit 14 | 5 | 20–45% | 37 moves: 16% | 40 moves: 31% |

Tiger 8 was too easy. Below 26 moves, cutting moves barely changed its win rate (about 55–60%), because its losses come down to the last one or two locks. 24 moves together with both collection goals raised to 24 brought it into band. Removing its pre-placed Lightning was tried and made no real difference, so the board keeps it.

The bands were set for tuning new chapters. Many earlier levels, especially the Rat chapter, which teaches the basics, are easier than their difficulty number suggests. That was left as it is: making early levels harder is a product decision, not a balance fix.

## Saved progress fallback

`RecordManager` used to call `fatalError` when the SwiftData store could not be opened, for example on a full disk or after a failed migration. That crashed the app on every launch. It now falls back to an in-memory store, so the game starts. The file on disk is left untouched, so a later launch can open it again.

If a later launch finds an empty store, `GameModel.initializeRecords` sets the map up as on a first launch instead of showing a blank map. A failed fetch is never treated as empty, so saved records are never duplicated.
