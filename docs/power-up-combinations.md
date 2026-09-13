# Festival power-up combinations

Five has a golden halo with five orbiting glints. Lightning has a slow-pulsing electrical border. Both accents stay inside their tile, pause with the board, and become static when reduced effects are enabled.

Swapping adjacent power-ups activates one combined clear, regardless of swap order. Each swap spends one move. Overlapping areas are merged before removal, so a tile contributes score and collection progress once.

| Pair | Elimination | Animation |
| --- | --- | --- |
| Five + Lightning | Converts the most common normal color into Lightning, then fires every converted bolt and the original Lightning together | Red connections charge the matching tiles; their artwork changes to Lightning before all affected rows and columns ignite simultaneously |
| Five + Five | Every occupied cell, including armor, ice, locks, ingredients and every jelly layer | Twin stars converge into a board-sized sunburst with concentric waves and sixteen firework spokes |
| Lightning + Lightning | Three-wide crosses and diagonals through both sources | A broad thunder cross with diagonal forks |
| Enhanced Four + Lightning | Five-wide cross at Lightning, plus a 5 × 5 blast at Enhanced Four | Red firecracker shockwave with thick red-and-gold lanes |
| Enhanced Four + Five | Converts matching colors into Enhanced Four, then detonates their ordinary 3 × 3 blasts together | Connections charge matching tiles; their artwork gains the enhanced border, then every blast ring blooms simultaneously |

Conversion uses a snapshot of the board. Enhanced Four supplies its own color; Five + Lightning uses the most common color, with a stable tie-break independent of swap direction. Armor and frozen pieces retain their protection rather than converting into a charged piece. Converted pieces still count toward their original color goals, and each converted piece's activation advances the relevant special goal.

## Chain reactions

Explosions and Lightning activate Enhanced Four, Lightning, and Five pieces they hit. A queue resolves all connected reactions before the board falls. Each power activates once, even when blasts overlap or return to an earlier source. A hit Five clears the initiating color; that color stays the same through intervening explosions or Lightning. Protected specials absorb the hit without firing. Double Five keeps its complete-board clear without redundantly activating every removed special.

One presentation batch owns the conversion, simultaneous release, and reactions. Converted artwork appears at 0.18 seconds; every converted power releases at 0.52 seconds. Those combinations last 1.16 seconds, double Five lasts 1.12 seconds, and the other combinations last 0.96 seconds. Reduced effects use the converted artwork with a short fade and omit moving beams, rings, and shake. Restart removes old effect nodes and prevents old actions from altering the new board.

## Trying them

Open Debug Menu → Power-up Combinations and choose a pairing. Swap the two charged center tiles. Pause → Restart restores that pairing without leaving the demo.

## Verification

Targeted simulator regressions cover:

- Exact conversion membership, ordinary blast footprints, both swap orders, edges, and collection credit for original colors.
- Recursive Enhanced Four → Lightning → Five → Enhanced Four → Lightning activation with the original color, no duplicate clears or activations, and armor resistance to overlapping blasts.
- Special tiles hit by both conversion combinations and regular Lightning swaps; a Lightning's row and column count as one activation.
- Full double-Five protection and goal clearing, plus source and converted-special goal credit.
- Native SpriteKit conversion artwork before release, simultaneous release timing, reaction effects, reduced effects, and effect cleanup.
- Restart during conversion and invalidation of an old in-flight move.

Native screenshots capture both the conversion and release stages.
