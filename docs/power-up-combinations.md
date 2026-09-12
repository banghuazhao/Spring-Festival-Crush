# Festival power-up combinations

Five now has a golden halo with five orbiting glints. Lightning has a slow-pulsing electrical border. Both accents stay inside their tile, pause with the board, and become static when reduced effects are enabled.

Swapping adjacent power-ups activates one combined clear, regardless of swap order. Each swap spends one move. Overlapping areas are merged before removal, so a tile contributes score and collection progress once.

| Pair | Elimination | Animation |
| --- | --- | --- |
| Five + Lightning | Row and column blasts through every tile of the most common normal color, plus a three-wide cross through both sources | The charms converge into a constellation of red connections and golden lightning lanes |
| Five + Five | Every occupied cell, including armor, ice, locks, ingredients and every jelly layer | Twin stars converge into a board-sized sunburst with concentric waves and sixteen firework spokes |
| Lightning + Lightning | Three-wide crosses and diagonals through both sources | A broad thunder cross with diagonal forks |
| Enhanced Four + Lightning | Five-wide cross at Lightning, plus a 5 × 5 blast at Enhanced Four | Red firecracker shockwave with thick red-and-gold lanes |
| Enhanced Four + Five | 5 × 5 blasts centered on every tile matching the enhanced piece’s color | Linked rockets with overlapping golden blast rings and red sparks |

The enlarged footprints include the ordinary effects and reach additional cells where space is available. Board edges and full-board saturation naturally limit the maximum clear. All combinations except double Five retain the existing one-hit-per-turn armor rule. Directly cleared ingredients now advance their goal instead of disappearing without credit.

Combined sources contribute their respective Five/Lightning/Enhanced goal activations. The initiating Enhanced Four is consumed by the combined footprint and cannot explode or receive activation credit a second time; other enhanced tiles caught in the blast retain their normal chain reactions.

Animation batches last 0.96 seconds, or 1.12 seconds for double Five. Effects are bounded, owned by one transient batch, and use the scene clock. Reduced effects skip convergence, beams, rings, sparks, and shake and use short tile fades. Restart removes the old effect batch.

## Trying them

Open Debug Menu → Power-up Combinations and choose a pairing. Swap the two charged center tiles. Pause → Restart restores that pairing without leaving the demo.

## Verification

Six targeted simulator tests passed:

- All five footprints beat the independent-effects footprint on the fixture, in both swap orders, horizontally and vertically, at the center and edge; scores and cell membership agree.
- Double Five removes armor/ice and credits locks, ingredients, all jelly layers, and two Five activations.
- Other pairs retain armor resistance and credit both source types without duplicating the initiating enhanced explosion.
- Every dedicated demo retains its pair on Restart.
- All five animations and both auras behave correctly in full and reduced effects, with no leftover effect nodes or removal bookkeeping.
- Existing individual power-up birth/clear regressions remain passing.

Reviewed native SpriteKit screenshots of every combination’s release. Debug build and `git diff --check` passed.
