#!/usr/bin/env bash
# scope-check.sh <base> <owned-paths-file>  — run in a lane worktree; deterministic gate the reviewer runs first.
# Owned file: one path per line; a line ending in / owns that directory. Blank lines and # comments ignored.
# Exit 0 in scope; 1 uncommitted work or a changed path outside ownership; 2 usage or bad base.
set -uo pipefail
[ -n "${1:-}" ] && [ -r "${2:-}" ] || { echo "usage: scope-check.sh <base> <owned-paths-file>"; exit 2; }
base=$1; owned=$2
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "bad base: $base"; exit 2; }
rc=0
# Untracked node_modules links and Serena state (.serena/, created by whatever tool opens the worktree) are not lane work.
dirty=$(git status --porcelain --untracked-files=all | grep -vE '^\?\? \.serena/' | grep -v ' node_modules' || true)
[ -z "$dirty" ] || { echo "UNCOMMITTED (review needs a committed revision):"; printf '%s\n' "$dirty"; rc=1; }
changed=$(git diff --name-only "$base"...HEAD)
n=0; out=0
while IFS= read -r f; do
  [ -n "$f" ] || continue; n=$((n+1)); ok=0
  while IFS= read -r p; do
    case "$p" in ''|'#'*) continue;; esac
    case "$p" in */) case "$f" in "$p"*) ok=1;; esac;; *) [ "$f" = "$p" ] && ok=1;; esac
  done < "$owned"
  if [ $ok = 1 ]; then
    h=$( { [ -f "$f" ] && { sha256sum "$f" 2>/dev/null || shasum -a 256 "$f"; } | cut -c1-12; } || echo deleted)
    echo "ok   $h $f"
  else echo "OUT  $f"; out=$((out+1)); rc=1; fi
done <<< "$changed"
echo "SCOPE: revision=$(git rev-parse HEAD) changed=$n out_of_scope=$out uncommitted=$([ -z "$dirty" ] && echo 0 || echo yes) -> $([ $rc = 0 ] && echo PASS || echo FAIL)"
exit $rc
