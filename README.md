# lanes: a token-efficient orchestration harness for Claude Code

`lanes` is a Claude Code skill that turns one session into an orchestrator. It audits a project, even one left half-finished, plans the remaining work, and runs it in parallel **lanes**, each lane being a git worktree with one agent working in it. It sends each job to the cheapest model that can do it well:

| Role | Model | Billed to |
|---|---|---|
| Orchestrator, migrations, live ops, design, first review of authority, money or security code | Claude (Opus/Sonnet) | your Claude subscription |
| Well-specified coding: features, fix rounds, refactors, tests | **DeepSeek** (`deepseek-flash`) or **GLM 5.3 Flash** (`z-ai/glm-5.3-flash` via OpenRouter) | your DeepSeek / OpenRouter API keys |
| Routine code reviews and re-reviews | **OpenAI Codex** (`gpt-5.6-terra`, Codex CLI) | your ChatGPT plan |

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

The installer checks prerequisites and both keys, and tells you exactly what to add if something is missing. It backs up any file it replaces. **Restart Claude Code afterwards** so the `deepseek`, `glm` and `codex` subagents load.

It installs:
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
rm -f ~/.claude/{deepseek,glm}.json ~/.claude/agents/{deepseek,glm,codex}.md
systemctl --user disable --now lanes-watchdog.timer 2>/dev/null; rm -rf ~/.claude/skills/lanes
```

MIT licensed. Not affiliated with Anthropic, OpenAI, DeepSeek, Z.ai or OpenRouter.
