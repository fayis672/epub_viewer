#!/usr/bin/env bash
# Peak memory of the reader while it opens the benchmark books, per loading
# mode, on an Android device or emulator.
#
#   cd example
#   tool/measure_memory.sh [device-serial]
#   MODES="memory" tool/measure_memory.sh   # one mode only
#
# Runs integration_test/epub_performance_test.dart once per mode
# (PERF_MODE=memory, then server; one round) and samples `dumpsys meminfo`
# every second. Reported: peak total PSS of the app process plus the WebView
# renderer (sandboxed_process), where epub.js and the book bytes live.
set -euo pipefail

SERIAL="${1:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
PKG="com.example.example"
OUT_DIR="$(mktemp -d)"

sample_pss() {
  # "Total PSS by process" lines, e.g. "  123,456K: com.example.example (pid 1)"
  adb -s "$SERIAL" shell dumpsys meminfo 2>/dev/null |
    awk -v pkg="$PKG" '
      /Total PSS by process/ {on=1; next}
      on && /^$/ {exit}
      on && (index($0, pkg) || index($0, "sandboxed_process")) {
        gsub(/[K,:]/, "", $1); sum += $1
      }
      END {print sum + 0}'
}

for MODE in ${MODES:-memory server}; do
  LOG="$OUT_DIR/$MODE.log"
  PEAK_FILE="$OUT_DIR/$MODE.peak"
  echo 0 > "$PEAK_FILE"
  flutter test integration_test/epub_performance_test.dart -d "$SERIAL" \
    --dart-define=PERF_MODE="$MODE" --dart-define=PERF_ROUNDS=1 > "$LOG" 2>&1 &
  TEST_PID=$!
  while kill -0 "$TEST_PID" 2>/dev/null; do
    PSS="$(sample_pss)"
    if [ "$PSS" -gt "$(cat "$PEAK_FILE")" ]; then echo "$PSS" > "$PEAK_FILE"; fi
    sleep 1
  done
  wait "$TEST_PID" || echo "($MODE run reported failures, see $LOG)"
  echo "MEMORY|android|$MODE|peak_pss_mb=$(( $(cat "$PEAK_FILE") / 1024 ))"
  grep -E "^PERF\|" "$LOG" | grep -v warm-up || true
done
echo "Logs: $OUT_DIR"
