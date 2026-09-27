#!/usr/bin/env bash
# lane-status.sh — one-call evidence table for "lane update". Registry: <state>/lanes.tsv
# (tab-separated: lane, agent, task, worktree-name-or-path or -, relay-job-dir or -). Edit rows at dispatch.
set -uo pipefail
. "$(dirname "$0")/lane-env.sh"; R=$(lanes_repo) || exit 1; S=$(lanes_state); now=$(date +%s)
[ -f "$S/lanes.tsv" ] || { printf '# lane\tagent\ttask\tworktree\trelay-job\n' > "$S/lanes.tsv"; echo "created $S/lanes.tsv (empty)"; }
base=$(git -C "$R" symbolic-ref --short HEAD 2>/dev/null || echo main)
printf '%s  %s %s  (registry %s)\n' "$(date +%H:%M)" "$base" "$(git -C "$R" rev-parse --short HEAD)" "$S/lanes.tsv"
printf '| Lane | Agent | Task | Commits | WIP files | Last edit | Running |\n|---|---|---|---|---|---|---|\n'
grep -v '^#' "$S/lanes.tsv" | while IFS=$'\t' read -r lane agent task wt job; do
  [ -n "${lane:-}" ] || continue; c=-; wip=-; last=-; run=""
  case "${wt:--}" in -) p="";; /*) p=$wt;; *) p="$R/.claude/worktrees/$wt";; esac
  if [ -n "$p" ] && [ -d "$p" ]; then
    c=$(git -C "$p" rev-list --count "$base"..HEAD 2>/dev/null || echo ?)
    files=$(git -C "$p" status --porcelain | grep -v node_modules | awk '{print $2}')
    wip=$(printf '%s' "$files" | grep -c . || true)
    t=$( (git -C "$p" log -1 --format=%ct; for f in $files; do stat -c %Y "$p/$f" 2>/dev/null; done) | sort -n | tail -1)
    [ -n "$t" ] && last="$(( (now - t) / 60 ))m ago"
    pgrep -af "vitest|jest|pytest|tsc -b|eslint|playwright|go test|cargo test" | grep -q -- "$p" && run="tests "
  fi
  if [ "${job:--}" != - ] && [ -d "$job" ]; then
    if [ -f "$job/rc" ]; then run="${run}relay done rc=$(cat "$job/rc")"; else run="${run}relay running $(( (now - $(stat -c %Y "$job/task.md")) / 60 ))m"; fi
  fi
  printf '| %s | %s | %s | %s | %s | %s | %s |\n' "$lane" "$agent" "$task" "$c" "$wip" "$last" "${run:--}"
done
echo "relay jobs (latest 5):"; for j in $(ls -td "$HOME"/.local/state/model-relay.* 2>/dev/null | head -5); do echo "  $j $(cat "$j/engine" 2>/dev/null) rc=$(cat "$j/rc" 2>/dev/null || echo running) cwd=$(cat "$j/cwd" 2>/dev/null)"; done
