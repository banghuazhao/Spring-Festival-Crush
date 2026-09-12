# Pause restart and Lucky Five feedback

Pause now offers Resume, Restart, Settings, and Exit. Restart reloads the current level or the same debug demo, resets score, authored goals, moves and timer, and clears temporary targeting and extra moves. Remaining tool inventory, coins, and lives are preserved. A fresh attempt identifier prevents an interrupted move from updating the replacement board.

Lucky Five uses a distinct red-and-gold festival sequence: a five-petal charge around the enlarged star, expanding warm rings, curved ribbons and traveling sparks toward matching tiles, then staggered tile pulses and collection. The impact haptic, sound accent, and optional shake coincide with release. Creation uses its own petal gathering/reveal animation. The normal activation batch completes in 0.76 seconds; birth completes in 0.48 seconds. Lightning retains its faster row/column trail.

Paths are capped at 24 per activation and all nodes belong to one transient clear batch. Reduced effects use the existing short fade and skip petals, ribbons, spark bursts, and shake. Tile-clear waits use the scene clock so detaching old sprites during Restart cannot strand that clear's task group.

## Verification

- Debug simulator build passed.
- Four targeted regressions passed across the verification runs: restart reset/inventory and both demos; restarting during a model clear; native SpriteKit restart during Five activation; power-up birth/clear cleanup in full and reduced motion.
- Inspected native frames from Five's charge, release, and final clear stages.
- Verified Pause → Restart → Pause on iPhone 17 and reviewed the four-button alert layout.
- `git diff --check` passed.
