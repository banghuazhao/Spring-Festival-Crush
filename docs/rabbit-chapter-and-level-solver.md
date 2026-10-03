# Rabbit chapter, Tiger 11–15 and the level solver (3.4)

## Level solver

`SpringFestivalCrushTests/LevelSimulator.swift` plays a level headlessly. It makes the same `Level` calls as `GameModel`: swap, power-up activation, cascades, blockers, guardian damage and raids, spreading chocolate, free reshuffles, and the Festival Finale that turns leftover moves into blasts. Tools, boosters, continues and the timer are left out, so it measures the level itself. If `GameModel`'s turn loop changes, update `LevelSimulator.play` to match.

Two bots play:

- **Sensible** scores every legal move from the board right after the swap. It prefers power-up swaps and combos, then 5-in-a-row, L/T and 4-in-a-row shapes, then pieces the goals still need, blossoms, tiles next to locks and ice, the guardian's weak spot, and moves low on the board (more cascades). It is a fair stand-in for a casual player, and weaker than a skilled one with boosters.
- **Random** picks any legal move. It is a floor: a level that random play can win is never a wall.

`tools/simulate_levels.sh` runs the report test in the simulator and writes [level-balance-report.md](level-balance-report.md):

| Column | Meaning |
|---|---|
| Win (sensible) | Share of sensible games won |
| ★ / ★★ / ★★★ | Share of games won with at least that many stars |
| Moves left | Median moves left over in wins |
| Win score | Median final score in wins, the yardstick for star thresholds |
| Loss progress | Average goal progress when a game is lost (near misses are high) |
| Short in losses | The goal furthest from done in lost games, e.g. `blossom 3.1/20` |
| Win (random) | Share of random games won |

On every normal test run, `LevelBalanceTests` also checks that the bot wins each level at least once within 150 games, that no level dead-ends without a shuffle, and that no lock goal asks for more locks than the board holds. That last check covers the bug fixed in 3.0, and it caught three new drafts that asked for more locks than they had. A game takes about 30 ms, so a 200-game report over all 60 levels takes about six minutes.

### Bands used to tune the new levels

The bands come from the 40 levels that had already shipped, where the sensible bot won about 95% of difficulty 1–2 levels and about 25–60% of difficulty 5 levels:

| Difficulty | Sensible win rate |
|---|---|
| 1 | 90% or more |
| 2 | 75–90% |
| 3 | 50–70% (a level that introduces a rule may be easier) |
| 4 | 35–55% |
| 5 | 20–45% |
| Guardian | about 30–45% |

### Findings on the shipped levels (not changed)

- **Every win is a 3-star win.** In all 40 shipped levels, the median winning score (4,000–22,000, boosted by the Festival Finale) is far above the 3-star threshold (about 2,000–3,000). Stars only record whether a level was beaten, so the star chests effectively open as the chapter is cleared. A possible fix is to set the thresholds from the report's winning-score column, for example ★ at any win, ★★ around the 40th percentile and ★★★ around the 80th. That changes the reward economy, so it is left as a product decision. The new levels keep the existing threshold scale so they are consistent with the old ones.
- **The Tiger curve has spikes.** Tiger 5 (difficulty 3) is won about 10% of the time, below several difficulty 5 levels, and Tiger 2 (difficulty 1) only about 58%. Ox 14 is at about 10%. These levels are worth a look with the solver.

## Tiger 11–15

- The Snowfang Tiger guardian moves from Tiger 10 to the new chapter finale, Tiger 15 (70 health, 29 moves), so every chapter ends on a guardian. Tiger 10 keeps its board and drops to 34 moves without the guardian.
- Tiger 11–15 are difficulty 5 and build on the chapter's ice, gold frames and double locks: a diagonal ring of double locks with frozen tiles (11), a board split by holes (12), rows of locks between ice and frames (13), an X of double locks (14), and the guardian fight among locks and frames (15).

## Rabbit chapter: Moon Blossom Garden

- **Moon blossoms.** The existing jelly layer is now presented as moon blossoms: pink squares behind the tile (pale needs one clear, deep pink needs two), with a 🌸 goal icon. They used to be a green tint drawn over the tiles, which no shipped level used. Their handbook rule, **Moon Blossom**, is taught on Rabbit 1–2.
- **Vault locks** (three matches to open) appear for the first time on Rabbit 6. Their rule is taught on Rabbit 6 and 8.
- **Jade Rabbit guardian** (Rabbit 15, 80 health): cleared lanterns deal 1 damage and opened locks deal 2. Every 3 moves the Rabbit hops into the marked column (pink outline on the board, column number in the HUD) and turns two tiles there into locks, top first. Its locks count against the shared 12-piece hazard budget, so the board always stays playable. Breaking its locks hurts it, so its own attack gives the player a way to fight back.
- The 15 levels ramp from difficulty 1 to 5 and introduce one idea at a time: blossoms, deep blossoms, ear-shaped boards, locks over blossoms, gold frames on blossoms, vaults, ice rings, an hourglass, a "mooncake" vault ring, a garden in full bloom, and the guardian.
- Chinese text for every new string is in both `zh-Hans` and `zh-Hant` (玉兔, 月下花, 宝库锁/寶庫鎖).

### Art still to make

Rabbit uses the fallback artwork: the generic board background and a 🐰 emoji for the zodiac tile. The Rat, Ox and Tiger chapters have painted assets. To match them, generate:

- `RabbitBoardBackground` with the same prompt template as [art/zodiac-board-backgrounds.md](art/zodiac-board-backgrounds.md). Use "RABBIT — MOON BLOSSOM GARDEN", a soft plum-pink and pearl palette, a small carved jade rabbit on the lower-left ledge, and plum blossom branches at the far edges. Then add it to `gameBackgrounds` in `Zodiac.swift`.
- `RabbitTile`, matching `RatTile`/`OxTile`/`TigerTile` (prepare it with `tools/prepare_tile.swift`). Then return it from `Zodiac.tileAssetName`.

## Progress fix for existing players

When new levels were added to a chapter, a player who had already beaten its old last level found the first new level locked, and had to replay the old last level to open it. `reconcileNewLevels` now unlocks the first new level when the old last level is complete. This matters for this release: anyone who finished Tiger 10 goes straight on to Tiger 11.
