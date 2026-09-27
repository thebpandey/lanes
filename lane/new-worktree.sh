#!/usr/bin/env bash
# new-worktree.sh <branch> [base]  — creates <repo>/.claude/worktrees/<branch> off base (default: current branch of the main checkout).
# JS monorepos: node_modules entries are symlinked to the main checkout's, EXCEPT the repo's own workspace
# packages, which are linked to THIS worktree's copies (otherwise cross-package tests silently test main).
set -euo pipefail
. "$(dirname "$0")/lane-env.sh"; R=$(lanes_repo)
b=${1:?usage: new-worktree.sh <branch> [base]}; base=${2:-$(git -C "$R" symbolic-ref --short HEAD)}
w="$R/.claude/worktrees/$b"; git -C "$R" worktree add -q -b "$b" "$w" "$base"
if [ -d "$R/node_modules" ] && [ -f "$R/package.json" ]; then
  mkdir -p "$w/node_modules"
  mapfile -t pkgs < <(cd "$w" && for f in $(python3 - <<'PY'
import json, glob
ws = json.load(open("package.json")).get("workspaces", [])
ws = ws.get("packages", []) if isinstance(ws, dict) else ws
for g in ws:
    for d in glob.glob(g):
        print(d)
PY
); do [ -f "$f/package.json" ] && printf '%s\t%s\n' "$f" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["name"])' "$f/package.json")"; done)
  own_scopes=$(printf '%s\n' "${pkgs[@]:-}" | awk -F'\t' '$2 ~ /^@/ {split($2,a,"/"); print a[1]}' | sort -u)
  for e in "$R"/node_modules/* "$R"/node_modules/.[!.]*; do [ -e "$e" ] || continue; n=$(basename "$e")
    if printf '%s\n' $own_scopes | grep -qx -- "$n"; then mkdir -p "$w/node_modules/$n"; for s in "$e"/*; do ln -sfn "$s" "$w/node_modules/$n/$(basename "$s")"; done; else ln -sfn "$e" "$w/node_modules/$n"; fi
  done
  for row in "${pkgs[@]:-}"; do [ -n "$row" ] || continue; dir=${row%%$'\t'*}; name=${row#*$'\t'}
    mkdir -p "$(dirname "$w/node_modules/$name")"; ln -sfn "$w/$dir" "$w/node_modules/$name"
    [ -d "$R/$dir/node_modules" ] && [ ! -e "$w/$dir/node_modules" ] && ln -sfn "$R/$dir/node_modules" "$w/$dir/node_modules"
  done
fi
echo "$w"
