# lanes: a token-efficient orchestration harness for Claude Code

`lanes` is a Claude Code skill that turns one session into an orchestrator. It audits a project, even one left half-finished, plans the remaining work, and runs it in parallel **lanes**, each lane being a git worktree with one agent working in it.

Every task is **triaged by complexity before dispatch**. The tier picks the model from the start: hard problems go straight to Opus, and only routine work goes to the cheap models (DeepSeek first, GLM for simple, bounded jobs).

| Tier | What it looks like | Dev lane | Billed to |
|---|---|---|---|
| **T3 Complex** | Ambiguous or cross-cutting work; concurrency or state machines; authority, security or money logic; migrations and contracts; unknown-root-cause debugging; live ops; design | **Claude Opus** (`opus-lane`, high effort) | your Claude subscription |
| **T2 Moderate** | Clear spec, but multi-file or needs design judgment | **Claude Sonnet** (`sonnet-lane`) | your Claude subscription |
| **T1 Routine** | Well-specified, local, with clear tests: small features, fix rounds, refactors, test gaps | **DeepSeek** (`deepseek-flash`, thinking on) as the primary coder; **GLM 5.3 Flash** (`z-ai/glm-5.3-flash` via OpenRouter) for simple, bounded work | your DeepSeek / OpenRouter API keys |
| **T0 Mechanical** | Sweeps, status, evidence | haiku or a script | your Claude subscription |

**Reviews:**
- **OpenAI Codex** (`gpt-5.6-terra`, on your ChatGPT plan) handles routine reviews and re-reviews.
- **Claude Opus** gives the first review of authority, security, money or migration code.
- **Orchestration and merges** run on Claude Opus.

**T1 split:** DeepSeek is the primary T1 coder. GLM 5.3 Flash takes only simple, bounded work (tests, docs-with-code, mechanical refactors, huge-context reading) and overflow when DeepSeek already has 2 jobs running. When a T1 review fails, the next fix round switches to the other model before the task moves up a tier. Track first-pass review rates per model and revisit the split after about 10 tasks each. Why: vendor-reported DeepSWE is 74.2 for DeepSeek-V4.1-Flash (Terminal-Bench 30) against 63.4 for GLM-5.3-Flash. DeepSeek bills thinking tokens as output ($0.60/M off-peak, $1.20/M peak), so a typical lane job costs about $0.04–0.19 off-peak; GLM's thinking cannot be disabled.

**Re-tiering:** a task only ever moves *up*. That happens when a lane reports it's harder or riskier than triaged, or after two failed reviews at the current tier.

![How lanes works: a Claude Opus orchestrator triages each task by complexity into git-worktree lanes: T3 complex work to a Claude Opus lane, T2 moderate to a Claude Sonnet lane, T1 routine to DeepSeek as the primary coder, with GLM 5.3 Flash for simple, bounded work, behind a guarded relay, T0 mechanical to haiku or a script. Every lane flows into an independent review (Codex, or Claude Opus for security, money and migrations), loops through fix rounds until clean, re-tiers upward if needed, then merges and is verified on main.](docs/lanes-infographic.png)

The quality gates don't change. Every change gets an independent review before merge, the author never reviews its own work, and merges are verified on the main branch.

## Why the relay design

A Claude Code subagent file can't point at another provider: it has no `baseUrl` field, and `model` only takes Claude models. So each external model runs as a **separate headless Claude Code process** pointed at that provider's Anthropic-compatible API (`claude-via <provider>`). A small **guarded relay subagent** hands tasks to it. A `PreToolUse` hook (`relay-guard`) blocks every command except the relay itself; without it, the small relay model does the task itself instead of delegating. Every run leaves a job record (`~/.local/state/model-relay.*`, `~/.local/state/codex-review.*`) with the model that actually did the work.

## Requirements

- Claude Code, `git`, `python3`, `curl`, and `bash` on Linux or macOS. The watchdog timer is Linux/systemd only.
- API keys, exported in your shell rc and never stored by this skill:
  - `DEEPSEEK_API_KEY`: create one at https://platform.deepseek.com/api_keys
  - `OPENROUTER_API_KEY`: create one at https://openrouter.ai/keys. Set a spend limit, and under Privacy block providers that train on prompts.
- Optional:
  - The Codex CLI (`npm i -g @openai/codex`, then `codex login`) for Codex reviews. Without it, reviews use Claude.
  - Docker, for disposable test databases.
  - Beads (`bd`) for issue tracking.

## Install

```bash
git clone https://github.com/thebpandey/lanes ~/.claude/skills/lanes
bash ~/.claude/skills/lanes/install.sh            # installs relays, configs, and the deepseek/glm/codex subagents
bash ~/.claude/skills/lanes/install.sh --smoke    # optional: one tiny task through each provider
bash ~/.claude/skills/lanes/install.sh --watchdog # optional (Linux): timer that cleans orphaned agent work
```

The installer checks prerequisites and both keys, and tells you exactly what to add if something is missing. It backs up any file it replaces. **Restart Claude Code afterwards** so the `deepseek`, `glm`, `codex`, `opus-lane` and `sonnet-lane` subagents load.

It installs:
- `~/.claude/agents/{opus-lane,sonnet-lane}.md`: tiered Claude lane coders (Opus at high effort, Sonnet at medium).
- In `~/.local/bin`: `claude-via`, `claude-deepseek`, `claude-glm`, `model-relay`, `relay-guard` and `codex-review`.
- `~/.claude/{deepseek,glm}.json`, which hold the base URL, the model and the *name* of the key variable.
- `~/.claude/agents/{deepseek,glm,codex}.md`.

## Use

In any git project, start Claude Code and say:

- `/lanes start`: audits the project (instructions, git history, worktrees, tracker), shows what's done, in progress, ready and blocked, asks a few setup questions one at a time, then runs the lanes.
- `lane update`: the active lanes, with agent, task, concrete progress and an estimated %.
- `lane update all`: every workstream task and its state.
- `pause lanes` / `resume the lanes`: safe pause notes per lane, and resuming into the same worktrees.

Direct commands, which cost no Claude tokens:

```bash
cd <worktree> && RELAY_WAIT_S=6000 model-relay deepseek < brief.md   # or: model-relay glm
cd <worktree> && RELAY_WAIT_S=6000 codex-review main < checklist.md
~/.claude/skills/lanes/lane/new-worktree.sh <branch>                  # worktree + monorepo node_modules wiring
~/.claude/skills/lanes/lane/lane-status.sh                            # evidence table for "lane update"
```

Model overrides: `DEEPSEEK_MODEL=deepseek-v4-pro`, `GLM_MODEL=z-ai/glm-5.3`, `CODEX_MODEL=...`. To add another Anthropic-compatible provider, drop a `~/.claude/<name>.json` next to the others.

## Safety notes

- **Data leaves your machine.** DeepSeek and GLM receive whatever the task gives them, and run with full shell access inside their worktree, with `.env` reads denied. Run them only in worktrees, and never give them secrets, credentials or customer data.
- **Costs:** `total_cost_usd` in a worker's output is priced as if the run were Claude, so ignore it. Check your real spend on the DeepSeek balance page and on `https://openrouter.ai/api/v1/key`.
- **Self-identification:** workers call themselves "Claude" because Claude Code's system prompt says so. The job record's `model:` line shows the real model.
- **Approvals:** the skill asks before pushes, deploys, external writes, and anything hard to undo.

## Uninstall

```bash
rm -f ~/.local/bin/{claude-via,claude-deepseek,claude-glm,model-relay,relay-guard,codex-review}
rm -f ~/.claude/{deepseek,glm}.json ~/.claude/agents/{deepseek,glm,codex,opus-lane,sonnet-lane}.md
systemctl --user disable --now lanes-watchdog.timer 2>/dev/null; rm -rf ~/.claude/skills/lanes
```

Website: https://thebpandey.github.io/lanes/

MIT licensed. Not affiliated with Anthropic, OpenAI, DeepSeek, Z.ai or OpenRouter.
