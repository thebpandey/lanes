#!/usr/bin/env bash
# integrate.sh [--classify] <lane-dir> <branch>  — the only way lane work reaches the main branch.
# Run from the main worktree with the integration branch checked out. <lane-dir> is $S/lanes/<lane>
# (owned.txt, review.md). --classify only prints TRIVIAL or REVIEW for the lane's diff.
# Merges only when the scope check passes AND either the change is TRIVIAL or review.md holds
# VERDICT: CLEAN for the branch's exact head revision.
# Exit 0 merged (or classified); 1 refused; 2 usage or wrong place; 3 merge conflict (aborted).
# ponytail: a review.md hand-written by the orchestrator would pass; reviewers write it, the skill forbids forging it.
set -uo pipefail
LK=${LANES_HOME:-$HOME/.claude/skills/lanes}
classify_only=0; [ "${1:-}" = --classify ] && { classify_only=1; shift; }
dir=${1:-}; br=${2:-}
[ -n "$dir" ] && [ -n "$br" ] && [ -r "$dir/owned.txt" ] || { echo "usage: integrate.sh [--classify] <lane-dir with owned.txt> <branch>"; exit 2; }
gd=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null); gc=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$gd" ] && [ "$gd" = "$gc" ] || { echo "REFUSED: run from the main worktree"; exit 2; }
rev=$(git rev-parse --verify -q "refs/heads/$br") || { echo "REFUSED: no branch $br"; exit 2; }
base=$(git merge-base HEAD "$rev")

# TRIVIAL = prose only, <= 40 changed lines, no deletes/renames, no agent-instruction, control or legal files.
classify() {
  local total=0 a d f
  [ -z "$(git diff --name-status "$base" "$rev" | grep -vE '^[AM]	')" ] || { echo "REVIEW (delete, rename or mode change)"; return; }
  while IFS=$'\t' read -r a d f; do
    [ "$a" != - ] || { echo "REVIEW (binary: $f)"; return; }
    total=$((total + a + d))
    case "$f" in *.md|*.mdx|*.txt|*.rst|*.adoc) ;; *) echo "REVIEW (not prose: $f)"; return;; esac
    case "/$f" in */.claude/*|*/.github/*|*/.agents/*|*/.codex/*) echo "REVIEW (control path: $f)"; return;; esac
    case "$(basename "$f")" in AGENTS.md|CLAUDE.md|SKILL.md|CODEX.md|GEMINI.md|LICENSE*|SECURITY*|PRIVACY*|TERMS*) echo "REVIEW (instruction or legal file: $f)"; return;; esac
  done < <(git diff --numstat "$base" "$rev")
  [ "$total" -le 40 ] || { echo "REVIEW ($total changed lines > 40)"; return; }
  echo "TRIVIAL ($total changed lines of prose)"
}
cls=$(classify); echo "$cls" | sed 's/^/class: /'
[ $classify_only = 0 ] || { echo "${cls%% *}"; exit 0; }

wt=$(git worktree list --porcelain | awk -v b="branch refs/heads/$br" '/^worktree /{w=substr($0,10)} $0==b{print w}')
[ -n "$wt" ] || { echo "REFUSED: no worktree for $br (scope check needs it)"; exit 1; }
(cd "$wt" && bash "$LK/lane/scope-check.sh" "$base" "$dir/owned.txt") || { echo "REFUSED: scope check failed"; exit 1; }

if [ "${cls%% *}" = TRIVIAL ]; then mode=trivial
else
  v="$dir/review.md"
  [ -s "$v" ] || { echo "REFUSED: needs an independent review; no $v"; exit 1; }
  grep -qx 'VERDICT: CLEAN' <(sed 's/[[:space:]]*$//' "$v") || { echo "REFUSED: verdict is not CLEAN"; exit 1; }
  grep -qx "REVISION: $rev" <(sed 's/[[:space:]]*$//' "$v") || { echo "REFUSED: review is for another revision (lane head $rev)"; exit 1; }
  mode=reviewed
fi

git merge --no-ff --no-edit "$br" >/dev/null 2>&1 || { git merge --abort 2>/dev/null; echo "CONFLICT: merge aborted; rebase the lane onto $(git symbolic-ref --short HEAD) in its worktree"; exit 3; }
m=$(git rev-parse HEAD)
echo "$(date -u +%FT%TZ) $mode $rev merge=$m" >> "$dir/integration.log"
echo "MERGED $mode $br $rev -> $m"
