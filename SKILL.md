---
name: lanes
description: Token-efficient multi-lane orchestration for Claude Code. Use it to start or resume work on an existing (possibly unfinished) project, run parallel worktree lanes, triage each task by complexity (Opus for complex work from the start, Sonnet for moderate, DeepSeek for routine with GLM for simple bounded work) and route reviews to Codex, and report status. Triggers: "/lanes", "lanes start", "resume the lanes", "lane update", "lane update all", "pause lanes", "set up the lanes harness".
---

# Lanes: orchestration harness

You are the orchestrator. You plan, dispatch, review gates, merge and report. You do not do lane work in your own context. Lane agents do the work in git worktrees and hand back short summaries.

Paths: `K=~/.claude/skills/lanes`. The per-project state dir comes from `S=$(. $K/lane/lane-env.sh; lanes_state)`, which is `~/.local/state/lanes/<repo>-<hash>/`. It holds `lanes.tsv` (the lane registry) and `lanes/<lane>/` (briefs, reports, reviews).

## 0. Setup check (first use on a machine, or when anything fails)

Run `bash $K/install.sh --check`. If something is missing, run `bash $K/install.sh` and relay its ACTION lines to the user exactly. Missing API keys are the user's job: they add `DEEPSEEK_API_KEY` from platform.deepseek.com and `OPENROUTER_API_KEY` from openrouter.ai/keys to `~/.bashrc`. Never ask the user to paste a key into the chat, and never write a key anywhere yourself.

After installing, the user must restart Claude Code before the `opus-lane`, `sonnet-lane`, `deepseek`, `glm` and `codex` subagents appear. Until then, use the direct commands in §3. They need no restart.

## 1. Start or resume on a project (`/lanes start`)

1. Read the project instructions (`AGENTS.md`, `CLAUDE.md`), the docs index, `git log --oneline -30`, `git worktree list`, open branches, and the tracker. Use Beads (`bd ready`, `bd list`) if present, then GitHub issues, then whatever the project uses. If the project has no tracker, ask the user whether to set up Beads. Don't invent a parallel TODO file.
2. Find unfinished work: worktrees with uncommitted changes (never reset them), unmerged branches, notes saying PAUSED, failing CI.
3. Build a short plan: done / in progress / ready / blocked, with dependencies. Give every open task a **tier** (§2), which decides its lane model before anything is dispatched. Show it as the "lane update all" table (§6).
4. Ask the user, one question at a time, only for what you cannot infer: lane cap (default 6 concurrent agents, reviews included), priorities, which actions need their approval (push, deploy, external writes), and the commit trailer policy.
5. Save these answers to this project's memory: cap, routing, approvals, report formats. Future sessions then resume without asking again.

## 2. Triage, then route (complexity decides the model from the start)

Before dispatching, give every task a **tier**, and record it in the tracker and in the lane's `lanes.tsv` agent column (e.g. `Opus (T3)`). Pick the highest tier any signal points to. When in doubt between two tiers, pick the higher one.

| Tier | Signals (any one is enough) | Dev lane | Review |
|---|---|---|---|
| **T3 Complex** (high reasoning) | Ambiguous or underspecified; cross-cutting or architectural; concurrency, races, locks or state machines; authority, security, money or privacy logic; schema migrations or shared contracts; debugging an unknown root cause; live ops or deploys; design and UX; hard to reverse | **`opus-lane`** (Opus, high effort) | Opus for authority, security, money or migrations; otherwise Codex |
| **T2 Moderate** | Clear spec, but spans several files or packages or needs design judgment; unfamiliar area of the codebase; moderate blast radius | **`sonnet-lane`** (Sonnet) | Codex |
| **T1 Routine** | Well-specified, local change with clear acceptance tests: small features, fix rounds from a review, refactors, test gaps, CI or scripts, docs-with-code | **`deepseek`** (primary); **`glm`** only for simple, bounded work (or `model-relay`) | Codex |
| **T0 Mechanical** | Sweeps, renames, status or evidence gathering | haiku or a script | none, or spot-check |

- **T1 model choice:** DeepSeek (`deepseek-flash`, thinking mode on, which is DeepSeek's default) is the primary T1 coder. GLM 5.3 Flash takes only simple, bounded work: tests, docs-with-code, mechanical refactors, reading a huge context, and overflow when DeepSeek already has 2 jobs running. When a T1 review fails, the next fix round switches to the other model before the task moves up to T2 or T3. Record each model's first-pass review result in the project's memory, and revisit the split after about 10 tasks each. Why: vendor-reported DeepSWE is 74.2 for DeepSeek-V4.1-Flash (Terminal-Bench 30) against 63.4 for GLM-5.3-Flash. DeepSeek thinking tokens bill as output ($0.60/M off-peak, $1.20/M peak), so a typical DeepSeek lane job costs about $0.04–0.19 off-peak. GLM's thinking cannot be disabled.
- **Re-tier upward:** re-tier as soon as a lane reports the task is harder or riskier than triaged, or after two failed reviews at the current tier. Never downgrade a task mid-flight.
- **Fix rounds:** they usually stay with the author's tier. A fix round for T3 code may go to T1 when the review findings are precise and local.
- **Review before merge:** every change gets an independent review, and the reviewer is never the author. Fix rounds loop until the review is CLEAN.
- **DeepSeek and GLM run only in worktrees,** never in a checkout holding `.env` or secrets. Never send external models secrets, credentials, customer or contact data, or exports.
- **If Codex is not installed,** use a Sonnet reviewer following `$K/rules/REVIEW_RULES.md`.
- **Tell the user the tier:** in "lane update" and "lane update all", show each task's tier next to its agent.

## 3. Dispatch

- **Worktree:** `$K/lane/new-worktree.sh <branch> [base]` creates `<repo>/.claude/worktrees/<branch>` and wires JS monorepo `node_modules` so workspace packages resolve to the worktree.
- **Registry:** add or replace the lane's row in `$S/lanes.tsv`: lane, agent, task, worktree, relay job.
- **Brief:** start from `$K/rules/brief-template.md` and keep it short. It must name the worktree path, the task id, the acceptance checks and the tests. For Claude agents, reference `$K/rules/LANE_RULES.md`. For DeepSeek and GLM, paste its contents, since they cannot see this skill.
- **T3 and T2 lanes:** `Agent` with `subagent_type: opus-lane` (T3) or `sonnet-lane` (T2). Until Claude Code restarts after install, use a plain `Agent` with model opus or sonnet.
- **T1 lanes (DeepSeek, or GLM for simple bounded work), preferred from the orchestrator:** Bash with `run_in_background: true`:
  `cd <worktree> && RELAY_WAIT_S=6000 model-relay deepseek < $S/lanes/<lane>/brief.md` (or `glm`, per the T1 model choice in §2). It costs no Claude tokens, and you are notified on completion. If the output says STILL RUNNING, run `model-relay --wait <job>`.
- **Codex review, preferred from the orchestrator:** Bash with `run_in_background: true`:
  `cd <worktree> && RELAY_WAIT_S=6000 codex-review <base-ref> < checklist.md`. The checklist is 3–10 task-specific lines, authority first.
- **Subagents** (`deepseek`, `glm`, `codex`) are guarded haiku relays. Use them when a Task-tool call is more convenient. Give them the worktree path and the full brief or checklist.
- **Every Claude lane brief** ends with "final message ≤ 12 lines; full report to `<scratch>/report.md`".
- **Verify who did the work:** every relay run leaves `~/.local/state/model-relay.*` or `~/.local/state/codex-review.*` with `engine`/`model`, `cwd`, `rc` and output. The `model:` line comes from real usage data. DeepSeek and GLM call themselves "Claude"; ignore that.

## 4. Per-task flow

triage (tier → lane model) → dev in worktree → independent review → fix rounds until CLEAN → `git merge --no-ff` into the main branch → run the changed suites plus typecheck on main → close the tracker item with evidence (SHA, counts) → remove the worktree and branch → push only if the user allows it (run the secret scan first, and only fast-forward) → refill the lane from the ready queue.

On the main checkout, stage explicit paths only. It may carry the user's local edits: never `commit -a`, and never overwrite or revert them. If a merge touches a file with local edits, save the local diff, merge, then re-apply it.

## 5. Token discipline

- **Keep reports out of your context:** lane agents write full reports to files and send ≤ 12-line summaries. Read a report file only when needed, and never paste big outputs; use `tail` and `grep`.
- **Status:** `$K/lane/lane-status.sh` gives the evidence table in one call.
- **Watchdog:** runs from a timer (`install.sh --watchdog`), not a session cron.
- **Restarts:** restart the orchestrator session at quiet points, when no Claude agent is mid-task. DeepSeek, GLM and Codex runs are detached and survive. Before restarting, write a pause note per lane in the tracker: worktree, SHA, uncommitted work, next step.
- **Relay scripts:** never edit them in place while jobs run. Re-run `install.sh`, which replaces them atomically.

## 6. Reports

- **"lane update":**
  - One lead line: are all lanes working or is any stuck, and how the % was estimated.
  - A table `| Lane | Agent (tier) | Active task | Where it is | Est. |`. "Where it is" is concrete: commits, files, the test running, minutes in. Est. is a labelled rough %, backed by evidence from `lane-status.sh`.
  - What merged or deployed since the last update.
  - Any problem found, and how you will handle it.
- **"lane update all":** one table of every workstream's tasks: done, in progress (with agent and %), ready, and blocked (with the gate or owner decision), built from the tracker plus live lane state.

## 7. Pause / resume

- **Pause:** stop at safe points. For each lane, write a tracker note "PAUSED <date time>" with worktree, SHA, uncommitted work, next step. Remove leftover test containers.
- **Resume:** subagents do not survive a session restart. Dispatch new ones into the SAME worktrees, telling them to continue the existing work. Reattach relay jobs with `model-relay --wait` or `codex-review --wait`.

Ask the user before anything outward-facing or hard to undo: pushes (unless pre-approved), deploys, external writes or sends, deleting branches with unmerged work, history rewrites. Ask one question per message.
