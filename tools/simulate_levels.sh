#!/bin/sh
# Level solver: plays every bundled level many times with a sensible bot and a random bot,
# then writes win rates, star rates and spare moves to docs/level-balance-report.md.
#
#   tools/simulate_levels.sh                    # all levels, 200 games each
#   SIM_RUNS=400 tools/simulate_levels.sh Rabbit Tiger_Level_12
#
# DESTINATION overrides the simulator (default: iPhone 17).
set -eu
cd "$(dirname "$0")/.."
LEVELS=$(echo "$*" | tr ' ' ',')
REPORT="$PWD/docs/level-balance-report.md"
DESTINATION=${DESTINATION:-"platform=iOS Simulator,name=iPhone 17"}

# xcodebuild hands TEST_RUNNER_-prefixed variables to the test process without the prefix.
export TEST_RUNNER_SIM_RUNS=${SIM_RUNS:-200}
export TEST_RUNNER_SIM_LEVELS="$LEVELS"
export TEST_RUNNER_SIM_REPORT="$REPORT"
LOG=$(mktemp -t simulate_levels)
if ! xcodebuild test -quiet \
    -project SpringFestivalCrush.xcodeproj -scheme SpringFestivalCrush \
    -destination "$DESTINATION" \
    -only-testing:SpringFestivalCrushTests/LevelBalanceTests/testBalanceReport >"$LOG" 2>&1; then
    grep -E "error|failed" "$LOG" | head -40
    echo "Build or test failed; full log: $LOG"
    exit 1
fi

cat "$REPORT"
echo "Report: $REPORT"
