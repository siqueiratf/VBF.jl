#!/usr/bin/env bash
# Keep the search running: start it again when no controller runs.
#
#   keepalive.sh STATE START_SCRIPT [SECONDS] [MIN_FREE_GB] [AUX_SCRIPT]
#
# Every SECONDS (default 600) the loop looks for a controller process. After two
# checks in a row with no controller, it runs START_SCRIPT, but only when the
# volume of STATE has more than MIN_FREE_GB + 18 GiB free (default 5 + 18), so it
# does not start a search that the storage guard stops at once.
# An explicit stop disables it: STATE/run/STOP (written by run.sh stop) or the
# file STATE/KEEPALIVE_OFF. Remove the file to enable it again.
# AUX_SCRIPT (optional) runs on every check while the controller runs; use it
# for idempotent starts of helper jobs (run.sh graph, run.sh reports).
set -u
state=${1:?STATE}; start=${2:?START_SCRIPT}; every=${3:-600}; min_free_gb=${4:-5}; aux=${5:-}
log() { echo "$(date -u +%FT%TZ) $*"; }
misses=0
log "keepalive: state $state, start $start, every ${every}s"
while true; do
  if [ -e "$state/KEEPALIVE_OFF" ] || [ -e "$state/run/STOP" ]; then
    misses=0
  elif pgrep -f "julia.*closure_run.jl" >/dev/null; then
    misses=0
    if [ -n "$aux" ]; then "$aux" >/dev/null 2>&1 || log "aux script failed with status $?"; fi
  else
    misses=$((misses + 1))
    free_gb=$(( $(df -B1 --output=avail "$state" | tail -1) / 1073741824 ))
    if [ "$misses" -ge 2 ] && [ "$free_gb" -gt $((min_free_gb + 18)) ]; then
      log "no controller for two checks, $free_gb GiB free: running $start"
      "$start" || log "start script failed with status $?"
      misses=0
    elif [ "$misses" -ge 2 ]; then
      log "no controller, but only $free_gb GiB free: waiting"
    fi
  fi
  sleep "$every"
done
