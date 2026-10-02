# Lanes in Codex

Use the main worktree for orchestration, planning, integration, and `session-detail` archives before context compaction. Do implementation in linked Git worktrees. Read this file with `SKILL.md`; apply the same ownership, privacy, tracker, and authorization rules.

## Model and effort defaults

- Orchestration and routine coordination: `gpt-6.1-sol`, medium effort.
- Claude Code default: Opus 5.5, medium effort.
- High effort: legal meaning, security, difficult defects, and final acceptance (`CODEX_EFFORT=high` for `codex-review`; medium is the default).
- Bounded structural checks: `gpt-6-luna` or a deterministic script.
- DeepSeek and GLM: simple, bounded tasks only. GLM is for especially small mechanical tasks.

## Dispatch contract

Keep each worker brief short and complete. Name the task inputs and completed boundary, exact file ownership, acceptance checks, token/output limits, and a stop condition. Never delegate vague or open-ended work. Start a fresh worker at a completed boundary when old history no longer helps. The main worktree does not own implementation tasks.

Capture completion events and exit status instead of repeatedly scanning every lane. From the brief's base SHA and owned-path list, run one deterministic final check that hashes changed files, counts required checks, confirms other owned paths stayed unchanged, and confirms no out-of-scope paths changed. Return failures and totals. Keep routine tool results to 1,000–2,000 tokens and worker summaries to 10–12 lines; read full reports only when a decision needs them.

Append one row per task to `$S/usage.tsv`: task/lane, model, input tokens, cached-input tokens, output tokens, failures/retries, acceptance (`accepted`, `rejected`, or `pending`), and evidence path. Use provider usage data and mark missing fields `n/a`. Default ceilings (fresh plus cached input / output) are 2,000/500 tokens for structural checks or short drafts, 12,000/4,000 for routine tasks, and 24,000/8,000 for moderate tasks. State the limit in every brief; stop and rebrief at the cap. Keep short-draft output at or below 500 tokens.

## Context recovery

Keep startup context to current Beads constraints and recovery pointers. Retrieve historical memories by topic. Before the first context compaction of a session, use `session-detail` to create one full archive. Before every later compaction, create one incremental archive with the verified checkpoint from the preceding archive. Include current session identity and covered position so the next boundary can be verified. Save the report before compacting and follow `session-detail`'s archive and privacy rules.

At integration, verify only assigned paths and expected changes. Preserve user edits, stage explicit paths, and follow project authorization for commits, merges, pushes, deploys, and external writes. Full worker evidence stays in its report file; the orchestrator reads it only to resolve a decision, a failed check, or acceptance.
