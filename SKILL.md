---
name: lanes
description: Use when coordinating parallel software work in Git worktrees, including starting or resuming lanes, dispatching bounded tasks, reviewing integration, or reporting lane status. Triggers: "/lanes", "lanes start", "resume the lanes", "lane update", "lane update all", "pause lanes", "set up the lanes harness".
metadata:
  intended_model: opus
---

# Lanes: orchestration harness

You are the orchestrator. You plan, dispatch, review gates, integrate and report. Do all implementation work in assigned worktrees. Use the main worktree only for orchestration, integration, planning, and writing session-detail logs before context compaction. Workers own only their assigned files in their assigned worktrees.

Paths: `K=~/.claude/skills/lanes`. The per-project state dir comes from `S=$(. $K/lane/lane-env.sh; lanes_state)`, which is `~/.local/state/lanes/<repo>-<hash>/`. It holds `lanes.tsv` (the lane registry) and `lanes/<lane>/` (briefs, reports, reviews). In Codex, also read [CODEX.md](CODEX.md).

## 0. Setup check (first use on a machine, or when anything fails)

Run `bash $K/install.sh --check`. If something is missing, run `bash $K/install.sh` and relay its ACTION lines to the user exactly. Missing API keys are the user's job: they add `DEEPSEEK_API_KEY` from platform.deepseek.com and `OPENROUTER_API_KEY` from openrouter.ai/keys to `~/.bashrc`. Never ask the user to paste a key into the chat, and never write a key anywhere yourself.

After installing, the user must restart Claude Code before the `opus-lane`, `sonnet-lane`, `deepseek`, `glm` and `codex` subagents appear. Until then, use the direct commands in §3. They need no restart.

## 1. Start or resume on a project (`/lanes start`)

1. Read project instructions (`AGENTS.md`, `CLAUDE.md`), the docs index, `git worktree list`, open branches, and the current tracker state. Use Beads (`bd ready`, `bd list`) when present and follow its project constraints. Keep startup notes to current Beads constraints and recovery pointers; retrieve historical memories by topic as needed. Read recent Git history only when it answers a live question. If the project has no tracker, use its existing convention; ask before introducing Beads. Don't invent a parallel TODO file.
2. Find unfinished work: worktrees with uncommitted changes (never reset them), unmerged branches, notes saying PAUSED, failing CI.
3. Build a short plan: done / in progress / ready / blocked, with dependencies. Give every open task a **tier** (§2), which decides its lane model before anything is dispatched. Show it as the "lane update all" table (§6).
4. Ask only for decisions that cannot be inferred: lane cap, priorities, approval limits, and commit trailer policy.
5. Save durable decisions and recovery pointers in the project's tracker or memory. Keep startup notes short; retrieve historical memories by topic.

## 2. Triage, then route (complexity decides the model from the start)

Before dispatching, give every task a **tier**, and record it in the tracker and in the lane's `lanes.tsv` agent column (e.g. `Opus (T3)`). Pick the highest tier any signal points to. When in doubt between two tiers, pick the higher one.

| Tier | Signals (any one is enough) | Dev lane | Review |
|---|---|---|---|
| **T3 Complex** | Legal meaning, security, difficult defects, or final acceptance | Codex Sol or Claude Opus 5.5 at high effort | Independent high-effort review |
| **T2 Moderate** | Clear multi-file work needing judgment, cross-cutting changes, or unfamiliar code | Codex Sol at medium effort; `sonnet-lane` at medium effort when a Claude coding worker fits | Codex Sol at medium effort |
| **T1 Routine** | Well-specified coding or docs task with clear acceptance checks | DeepSeek; GLM for simple bounded tasks | Codex Sol at medium effort |
| **T0 Structural** | Bounded counts, hashes, format and unchanged-file checks | Codex Luna or deterministic scripts | Deterministic result; inspect failures only |

- **Routine coordination:** use gpt-6.1-sol at medium effort in Codex and Opus 5.5 at medium effort in Claude Code. Raise effort to high only for legal meaning, security, difficult defects, or final acceptance. Use Luna for bounded structural checks. Use DeepSeek and GLM only for simple, self-contained tasks; choose GLM for the smallest mechanical tasks.
- **Re-tier upward:** re-tier as soon as a lane reports the task is harder or riskier than triaged, or after two failed reviews at the current tier. Never downgrade a task mid-flight.
- **Fix rounds:** they usually stay with the author's tier. A fix round for T3 code may go to T1 when the review findings are precise and local.
- **Review before merge:** every change gets an independent review, and the reviewer is never the author. Fix rounds loop until the review is CLEAN.
- **DeepSeek and GLM run only in linked worktrees with no `.env` files;** `model-relay` refuses anything else. Never send external models secrets, credentials, customer or contact data, or exports.
- **If Codex is not installed,** use a Sonnet reviewer following `$K/rules/REVIEW_RULES.md`.
- **Tell the user the tier:** in status summaries, show each task's tier and assigned model.

## 3. Dispatch

- **Worktree:** `$K/lane/new-worktree.sh <branch> [base]` creates `<repo>/.claude/worktrees/<branch>` and wires JS monorepo `node_modules` so workspace packages resolve to the worktree.
- **Registry:** add or replace the lane's row in `$S/lanes.tsv`: lane, agent, task, worktree, relay job.
- **Brief:** start from `$K/rules/brief-template.md` and keep it short and complete. State inputs, exact file ownership, acceptance checks, tests, token/output cap, and a stop condition. Give the worker a completed boundary; start a fresh worker when prior history no longer helps. For Claude agents, reference `$K/rules/LANE_RULES.md`. For DeepSeek and GLM, paste it.
- **T3 and T2 lanes:** `Agent` with `subagent_type: opus-lane` (T3) or `sonnet-lane` (T2). Until Claude Code restarts after install, use a plain `Agent` with model opus or sonnet.
- **T1 lanes (DeepSeek, or GLM for simple bounded work), preferred from the orchestrator:** Bash with `run_in_background: true`:
  `cd <worktree> && RELAY_WAIT_S=6000 model-relay deepseek < $S/lanes/<lane>/brief.md` (or `glm`, per the T1 model choice in §2). It costs no Claude tokens, and you are notified on completion. If the output says STILL RUNNING, run `model-relay --wait <job>`.
- **Codex review, preferred from the orchestrator:** Bash with `run_in_background: true`:
  `cd <worktree> && RELAY_WAIT_S=6000 codex-review <base-ref> < checklist.md`. The checklist is 3–10 task-specific lines, authority first.
- **Subagents** (`deepseek`, `glm`, `codex`) are guarded haiku relays. Use them when a Task-tool call is more convenient. Give them the worktree path and the full brief or checklist.
- Every worker returns a 10–12-line summary; full evidence stays in `<scratch>/report.md`. Routine tool-result payloads target 1,000–2,000 tokens. Read full evidence only when a decision needs it.
- **Verify who did the work:** every relay run leaves `~/.local/state/model-relay.*` or `~/.local/state/codex-review.*` with `engine`/`model`, `cwd`, `rc` and output. The `model:` line comes from real usage data. DeepSeek and GLM call themselves "Claude"; ignore that.

## 4. Per-task flow

Copy this checklist into the lane's tracker note and tick items as they complete:

```text
- [ ] 1. Triage: tier and lane model recorded
- [ ] 2. Dev in worktree; completion event received
- [ ] 3. Deterministic reconciliation check passed
- [ ] 4. Independent review; fix rounds until CLEAN
- [ ] 5. Integrate in the main worktree
- [ ] 6. Required checks pass
- [ ] 7. Tracker item closed with evidence (SHA, hashes, counts, unchanged files)
- [ ] 8. Worktree and branch removed
- [ ] 9. Pushed (only if authorized)
- [ ] 10. Refill from the ready queue
```

- **Step 3 or 4 fails:** return to step 2 in the same worktree with the findings. After the second failed review, re-tier (§2) before returning.
- **Step 5:** `git merge --no-ff --no-edit <branch>` on the main worktree; record the merge SHA in the tracker. On a conflict, `git merge --abort`, then return to step 2 to rebase the lane onto the main branch.
- **Step 6 fails:** `git revert --no-edit -m 1 <merge-sha>` on the main worktree, return to step 2 in the lane worktree with the failing output, then repeat steps 3 to 6.
- **Step 8:** run `git worktree remove <path>` (never `--force`), then `git branch -d <branch>`. If either refuses (dirty worktree or unmerged branch), stop and report it; use `git branch -D` only when `git cherry <main-branch> <branch>` prints no `+` lines (every commit already integrated).
- **Step 9:** only with push authorization. The scan must exit 0 first (1 = leaks, 2 = scanner or range problem); any non-zero exit blocks the push and goes to the user:

  ```sh
  base=$(git merge-base HEAD origin/<branch> 2>/dev/null || git merge-base HEAD origin/<main-branch>)
  bash $K/lane/secret-scan.sh "$base" HEAD && git push origin <branch>
  ```

  Never pass `--force`; a rejected non-fast-forward push is reported, not overridden.

On the main worktree, do only orchestration, planning, and integration. Stage explicit paths only. Preserve local edits: never `commit -a`, overwrite, or revert them. If a merge touches a file with local edits, preserve the diff, integrate, then re-apply it.

## 5. Token discipline

- **Completion events:** use worker/relay completion notifications and recorded exit status. Do not repeatedly scan all lanes for progress. From the brief's base SHA and owned-path list, run one deterministic final check that hashes changed files, counts required checks, confirms other owned paths stayed unchanged, and confirms no out-of-scope paths changed. Return failures and totals only. Use `lane-status.sh` once at startup or when a specific inconsistency needs investigation.
- **Compact evidence:** worker summaries are 10–12 lines. Routine tool results should be capped at 1,000–2,000 tokens. Keep detailed reports on disk and read them only to resolve a decision or failure.
- **Usage ledger:** append one row per task to `$S/usage.tsv`: task/lane, model, input tokens, cached-input tokens, output tokens, failures/retries, acceptance (`accepted`, `rejected`, or `pending`), and evidence path. Use provider-reported usage; mark unavailable fields `n/a`, never estimate them as observed facts. Default task ceilings (fresh plus cached input / output): structural or draft 2,000/500 tokens; routine 12,000/4,000; moderate 24,000/8,000. State the cap in the brief; stop and rebrief if reached. A larger cap needs a short reason. Keep brief-draft outputs at or below 500 tokens.
- **Watchdog:** runs from a timer (`install.sh --watchdog`), not a session cron.
- **Context compaction:** before the first context compaction in each session, create one full archive with the `session-detail` skill. Before each later compaction in that session, create one incremental archive using the verified checkpoint from the previous archive. Include the current session identity and covered position so the next boundary can be verified. `session-detail` prints to chat in Claude Code and writes no file, so write the printed archive verbatim to `$S/sessions/<its suggested filename>` yourself. Do not compact until that file exists. Keep current Beads constraints and recovery pointers in the archive; follow `session-detail` format and privacy rules.
- **Restarts:** restart the orchestrator session at quiet points. Before restarting, write a pause note per active lane in the tracker: worktree, SHA, uncommitted work, and next step.
- **Relay scripts:** never edit them in place while jobs run. Re-run `install.sh`, which replaces them atomically.

## 6. Reports

- **Status reports:** target 10–12 lines. Lead with blockers or completed events, then list only changed lane states, decisions, and next steps. Avoid speculative percentages and repeated full status tables. `lane update all` may use one concise table when the user needs the whole tracker.

## 7. Pause / resume

- **Pause:** stop at safe points. For each lane, write a tracker note "PAUSED <date time>" with worktree, SHA, uncommitted work, next step. Remove its test containers: `docker ps -aq --filter label=lanes.lane=<lane> | xargs -r docker rm -f`.
- **Resume:** subagents do not survive a session restart. Dispatch new ones into the SAME worktrees, telling them to continue the existing work. Reattach relay jobs with `model-relay --wait` or `codex-review --wait`.

Ask the user before anything outward-facing or hard to undo: pushes (unless pre-approved), deploys, external writes or sends, deleting branches with unmerged work, history rewrites. Ask one question per message.
