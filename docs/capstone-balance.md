# Capstone balance sample

Final verification of Rat, Ox, Tiger and Rabbit level 20: **200 sensible and 100 random games per board, 1,200 games total**. The opt-in `LevelBalanceTests/testBalanceReport` generated these results using the existing solver; [the solver documentation](rabbit-chapter-and-level-solver.md) explains the columns.

Move limits are 20, 24, 28 and 24. Second- and third-star thresholds come from earlier independent tuning samples, rounded to the nearest 100 points. This final sample validates the shipped values rather than recalibrating them from the same outcomes.

Sensible-play win rates range from 43% to 63%. These games exclude tools, boosters, continues and timers; their sampled win rates are not forecasts of player results.

| Level | Diff | Moves | Win (sensible) | ★ | ★★ | ★★★ | Moves left | Win score | Win p40 / p80 | ★★ / ★★★ at | Loss progress | Short in losses | Win (random) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|
| Rat 20 | 5 | 20 | 63% | 63% | 38% | 15% | 8 | 28930 | 25070 / 39650 | 24800 / 37300 | 84% | lightningCombos 1.6/6 | 3% |
| Ox 20 | 5 | 24 | 52% | 52% | 30% | 10% | 7 | 20980 | 19400 / 26100 | 19600 / 26400 | 91% | lightningCombos 1.2/4 | 5% |
| Tiger 20 | 5 | 28 | 43% | 43% | 24% | 10% | 9 | 23020 | 20820 / 28350 | 21800 / 27900 | 85% | lightningCombos 1.7/5 | 0% |
| Rabbit 20 | 5 | 24 | 50% | 50% | 27% | 12% | 8 | 20470 | 17790 / 25770 | 19200 / 24600 | 95% | lightningCombos 1.2/4 | 7% |
