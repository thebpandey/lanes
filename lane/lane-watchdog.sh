#!/usr/bin/env bash
# lane-watchdog.sh [report|clean] — kills clearly orphaned lane work only (all projects):
# wait-loops > 2h, orphaned `tail -f` > 1h, test processes in deleted dirs or > 150 min,
# lane test containers (label lanes.lane, set per LANE_RULES.md) older than 4h.
set -u
MODE="${1:-report}"; killed=0; flagged=0
act() { if [ "$MODE" = clean ]; then kill "$1" 2>/dev/null && { echo "KILLED $1 ($2)"; killed=$((killed+1)); }; else echo "WOULD KILL $1 ($2)"; flagged=$((flagged+1)); fi; }
age() { ps -o etimes= -p "$1" 2>/dev/null | tr -d ' '; }
for pid in $(pgrep -f "until .*do sleep" 2>/dev/null); do et=$(age "$pid"); [ -n "$et" ] && [ "$et" -gt 7200 ] && act "$pid" "wait-loop $((et/60))m"; done
for pid in $(pgrep -f "tail .*-f " 2>/dev/null); do et=$(age "$pid"); pp=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '); [ -n "$et" ] && [ "$et" -gt 3600 ] && [ "$pp" = 1 ] && act "$pid" "orphan tail -f $((et/60))m"; done
for pid in $(pgrep -f "vitest|jest|pytest|/tsc |tsc -b|eslint|playwright" 2>/dev/null); do et=$(age "$pid"); [ -z "$et" ] && continue
  cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null); case "$cwd" in *"(deleted)"*) act "$pid" "cwd deleted"; continue;; esac
  case "$cwd" in */.claude/worktrees/*) [ "$et" -gt 9000 ] && act "$pid" "test proc $((et/60))m in $cwd";; esac; done
docker ps --filter label=lanes.lane --format '{{.ID}}\t{{.Names}}' 2>/dev/null | while IFS=$'\t' read -r id name; do
  started=$(docker inspect -f '{{.State.StartedAt}}' "$id" 2>/dev/null); s=$(date -d "$started" +%s 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - s )) -gt 14400 ]; then [ "$MODE" = clean ] && docker rm -f "$id" >/dev/null && echo "REMOVED container $name" || echo "WOULD REMOVE container $name"; fi
done
echo "--- load: $(cut -d' ' -f1-3 /proc/loadavg) | mode=$MODE killed=$killed flagged=$flagged"
