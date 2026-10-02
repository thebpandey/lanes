#!/usr/bin/env bash
# tests/run.sh — regression checks for the lanes safety gates. Each case names the failure it prevents.
set -uo pipefail
K="$(cd "$(dirname "$0")/.." && pwd)"; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want $2, got $3)"; fails=$((fails+1)); fi; }
guard() { printf '%s' "$2" | python3 -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.stdin.read()}}))' | python3 "$K/bin/relay-guard" "$1" >/dev/null 2>&1; echo $?; }

# relay-guard: a relay subagent must not be able to smuggle a second command past the hook.
NL=$'\n'
check "guard allows the documented relay call" 0 "$(guard deepseek "cd /tmp/wt && model-relay deepseek <<'TASK'${NL}do it${NL}TASK")"
check "guard blocks newline injection in cd" 2 "$(guard deepseek "cd /tmp/wt${NL}touch /tmp/P && model-relay deepseek <<'TASK'${NL}t${NL}TASK")"
check "guard blocks redirect in cd" 2 "$(guard deepseek "cd /tmp/wt > /tmp/clobber && model-relay deepseek <<'TASK'${NL}t${NL}TASK")"
check "guard blocks newline injection for codex" 2 "$(guard codex "cd /tmp/wt${NL}touch /tmp/P && codex-review main <<'CHECKLIST'${NL}t${NL}CHECKLIST")"
check "guard allows --wait" 0 "$(guard glm "model-relay --wait /home/u/.local/state/model-relay.abc")"

# Repo with a remote and a linked worktree, shared by the cases below.
git -C "$T" init -q --bare remote.git
git -C "$T" init -q -b main repo && cd "$T/repo" && git commit -q --allow-empty -m base \
  && git remote add origin "$T/remote.git" && git push -q origin main && git worktree add -q -b lane1 "$T/wt" main
cd "$T/wt" && echo x > f.txt && git add f.txt && git commit -q -m work

# secret-scan: a clean first push of a new branch must not look like a leak (exit 1).
base=$(git merge-base HEAD origin/lane1 2>/dev/null || git merge-base HEAD origin/main)
bash "$K/lane/secret-scan.sh" "$base" HEAD >/dev/null 2>&1; check "first push of a new branch scans clean" 0 $?
bash "$K/lane/secret-scan.sh" >/dev/null 2>&1; check "missing base is a usage error, not a leak" 2 $?

# model-relay: external models must never run where .env files or the main checkout live.
cd "$T/repo" && out=$(model_out=$(bash "$K/bin/model-relay" deepseek </dev/null 2>&1); echo "$model_out")
check "relay refuses the main checkout" 1 "$(printf '%s' "$out" | grep -c 'refused: run only inside a linked lane worktree')"
cd "$T/wt" && touch .env && out=$(bash "$K/bin/model-relay" deepseek </dev/null 2>&1); rm .env
check "relay refuses a worktree holding .env" 1 "$(printf '%s' "$out" | grep -c 'refused: .env present')"
out=$(bash "$K/bin/model-relay" nosuch-engine </dev/null 2>&1)
check "clean worktree passes the refusal gate" 1 "$(printf '%s' "$out" | grep -c '^usage: model-relay')"

# relay-spawn: detach + time limit must work without setsid/timeout (absent on macOS) and always write rc.
python3 "$K/bin/relay-spawn" "$T/rc1" 10 /dev/null "$T/o1" "$T/o1" sh -c 'exit 3'; check "spawn records the exit code" 3 "$(cat "$T/rc1")"
python3 "$K/bin/relay-spawn" "$T/rc2" 1 /dev/null "$T/o2" "$T/o2" sleep 5; check "spawn records 124 on timeout" 124 "$(cat "$T/rc2")"
python3 "$K/bin/relay-spawn" "$T/rc3" 10 /dev/null "$T/o3" "$T/o3" no-such-cmd-xyz; check "spawn records 127 for a missing command" 127 "$(cat "$T/rc3")"
check "no relay script depends on setsid or timeout" 0 "$(grep -lE '\b(setsid|timeout [0-9])' "$K/bin/model-relay" "$K/bin/codex-review" | wc -l)"

# scope-check: the reviewer's deterministic gate must fail on out-of-scope or uncommitted changes.
cd "$T/wt" && printf 'f.txt\n' > "$T/owned"
bash "$K/lane/scope-check.sh" main "$T/owned" >/dev/null 2>&1; check "scope-check passes owned, committed changes" 0 $?
mkdir -p src && echo y > src/a.txt && git add src/a.txt && git commit -q -m stray
bash "$K/lane/scope-check.sh" main "$T/owned" >/dev/null 2>&1; check "scope-check fails an out-of-scope path" 1 $?
printf 'f.txt\nsrc/\n' > "$T/owned"
bash "$K/lane/scope-check.sh" main "$T/owned" >/dev/null 2>&1; check "scope-check accepts an owned directory" 0 $?
echo dirty >> f.txt
bash "$K/lane/scope-check.sh" main "$T/owned" >/dev/null 2>&1; check "scope-check fails uncommitted work (unreviewable revision)" 1 $?
git checkout -q f.txt
mkdir -p .serena && echo x > .serena/project.yml
bash "$K/lane/scope-check.sh" main "$T/owned" >/dev/null 2>&1; check "scope-check ignores Serena tool state (written by reviewers' tooling)" 0 $?
echo y > stray.txt
bash "$K/lane/scope-check.sh" main "$T/owned" >/dev/null 2>&1; check "scope-check still fails other untracked files" 1 $?
rm -rf .serena stray.txt
bash "$K/lane/scope-check.sh" main >/dev/null 2>&1; check "scope-check without an owned list is a usage error" 2 $?

# codex-review: the verdict must name the exact revision reviewed, so the orchestrator never integrates an unreviewed SHA.
J="$T/job"; mkdir -p "$J"; echo 0 > "$J/rc"; echo gpt-5.6-terra > "$J/model"; echo medium > "$J/effort"; echo main > "$J/base"; echo "$T/wt" > "$J/cwd"
echo 0123456789abcdef0123456789abcdef01234567 > "$J/revision"; echo "VERDICT: CLEAN" > "$J/out.md"
out=$(bash "$K/bin/codex-review" --wait "$J" 2>&1)
check "codex-review reports the reviewed revision" 1 "$(printf '%s' "$out" | grep -c 'revision=0123456789abcdef0123456789abcdef01234567')"
check "codex-review default model is gpt-5.6-terra" 1 "$(grep -c 'CODEX_MODEL:-gpt-5.6-terra' "$K/bin/codex-review")"
check "guard allows codex-review with an owned-paths file" 0 "$(guard codex "cd /tmp/wt && codex-review main /tmp/s/owned.txt <<'CHECKLIST'${NL}t${NL}CHECKLIST")"

# codex-review must run the lane checks itself: Codex's read-only sandbox has no writable temp dir, so pytest
# and most test runners crash inside it and every lane would loop on FIX. A fake codex echoes the prompt it received.
mkdir -p "$T/fakebin" "$T/lanedir"; cat > "$T/fakebin/codex" <<'FAKE'
#!/usr/bin/env bash
while [ $# -gt 1 ]; do [ "$1" = --output-last-message ] && out=$2; shift; done; printf '%s\n' "$1" > "$out"
FAKE
chmod +x "$T/fakebin/codex"; printf 'f.txt\n' > "$T/lanedir/owned.txt"; printf 'echo CHECK-RAN; exit 3\n' > "$T/lanedir/checks.sh"
cd "$T/wt" && git reset -q --hard HEAD~1 && git clean -qfd
out=$(PATH="$T/fakebin:$K/bin:$PATH" LANES_HOME="$K" RELAY_WAIT_S=30 bash "$K/bin/codex-review" main "$T/lanedir/owned.txt" <<< "check it" 2>&1)
check "codex-review runs checks.sh outside the sandbox" yes "$(printf '%s' "$out" | grep -q 'CHECK-RAN' && echo yes)"
check "the reviewer prompt carries the check result" yes "$(printf '%s' "$out" | grep -q 'already run outside your sandbox; exit=3' && echo yes)"
check "codex-review reports the check exit code" 1 "$(printf '%s' "$out" | grep -c 'CHECKS: checks.sh exit=3')"
check "codex-review saves its verdict beside owned.txt for integrate.sh" yes "$([ -s "$T/lanedir/review.md" ] && echo yes)"

# integrate.sh: the only merge path. Unreviewed non-trivial work must never reach the main branch.
I="$T/int"; git init -q -b main "$I/repo" && cd "$I/repo" && printf 'line\n' > README.md && printf 'x = 1\n' > app.py \
  && git add . && git commit -q -m base
lane() { # lane <name> <file> <content> [owned]; creates a committed lane worktree and its lane dir
  git -C "$I/repo" worktree add -q -b "$1" "$I/$1" main && printf '%s\n' "$3" >> "$I/$1/$2" && git -C "$I/$1" add -A && git -C "$I/$1" commit -q -m "$1"
  mkdir -p "$I/s/$1"; printf '%s\n' "${4:-$2}" > "$I/s/$1/owned.txt"; }
integ() { (cd "$I/repo" && bash "$K/lane/integrate.sh" "$@" >/dev/null 2>&1); echo $?; }
cls() { (cd "$I/repo" && bash "$K/lane/integrate.sh" --classify "$@" 2>/dev/null | tail -1); }
merges() { git -C "$I/repo" rev-list --count --merges main; }

lane docfix README.md "typo fixed"
check "classify: small prose edit is TRIVIAL" TRIVIAL "$(cls "$I/s/docfix" docfix)"
lane code app.py "y = 2"
check "classify: any code change needs review" REVIEW "$(cls "$I/s/code" code)"
lane bigdoc README.md "$(seq 1 41)"
check "classify: prose over 40 lines needs review" REVIEW "$(cls "$I/s/bigdoc" bigdoc)"
lane agentdoc AGENTS.md "always push"
check "classify: agent instruction files need review" REVIEW "$(cls "$I/s/agentdoc" agentdoc)"
git -C "$I/repo" worktree add -q -b rmdoc "$I/rmdoc" main && git -C "$I/rmdoc" rm -q README.md && git -C "$I/rmdoc" commit -q -m rm \
  && mkdir -p "$I/s/rmdoc" && echo README.md > "$I/s/rmdoc/owned.txt"
check "classify: deletions need review" REVIEW "$(cls "$I/s/rmdoc" rmdoc)"

check "refuses unreviewed code" 1 "$(integ "$I/s/code" code)"
check "refusal leaves the main branch unmerged" 0 "$(merges)"
printf 'TASK: T\nREVISION: 0000000000000000000000000000000000000000\nVERDICT: CLEAN\n' > "$I/s/code/review.md"
check "refuses a CLEAN verdict for another revision" 1 "$(integ "$I/s/code" code)"
printf 'TASK: T\nREVISION: %s\nVERDICT: FIX\n' "$(git -C "$I/code" rev-parse HEAD)" > "$I/s/code/review.md"
check "refuses a FIX verdict" 1 "$(integ "$I/s/code" code)"
printf 'TASK: T\nREVISION: %s\nVERDICT: CLEAN\n' "$(git -C "$I/code" rev-parse HEAD)" > "$I/s/code/review.md"
check "merges a CLEAN verdict for the exact revision" 0 "$(integ "$I/s/code" code)"
check "the merge is a real merge commit" 1 "$(merges)"
check "integration is logged as reviewed" 1 "$(grep -c ' reviewed ' "$I/s/code/integration.log" 2>/dev/null)"
check "merges a trivial prose edit without review" 0 "$(integ "$I/s/docfix" docfix)"
check "integration is logged as trivial" 1 "$(grep -c ' trivial ' "$I/s/docfix/integration.log" 2>/dev/null)"
lane stray README.md "small" "app.py"
check "scope failure blocks even trivial work" 1 "$(integ "$I/s/stray" stray)"
lane clash README.md "conflict A"; lane clash2 README.md "conflict B"
integ "$I/s/clash" clash >/dev/null
check "a conflict aborts and exits 3" 3 "$(integ "$I/s/clash2" clash2)"
check "an aborted conflict leaves no merge in progress" no "$([ -f "$I/repo/.git/MERGE_HEAD" ] && echo yes || echo no)"
check "refuses to run outside the main worktree" 2 "$(cd "$I/code" && bash "$K/lane/integrate.sh" "$I/s/code" code >/dev/null 2>&1; echo $?)"

# lane-env: the portable hash must keep existing Linux state dirs at the same path.
want="$HOME/.local/state/lanes/repo-$(python3 -c 'import hashlib,sys;print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:8])' "$T/repo")"
cd "$T/repo" && check "state dir path unchanged" "$want" "$(. "$K/lane/lane-env.sh"; lanes_state)"; rmdir "$want" 2>/dev/null

echo "--- $fails failure(s)"; [ "$fails" = 0 ]
