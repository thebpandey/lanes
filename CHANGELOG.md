# Changelog

## 0.1.0 — 2026-10-01

Initial versioned release of the refreshed lanes workflow.

- Recommend Codex Sol at medium effort and Claude Opus 5.5 at medium effort for orchestration; reserve high effort for legal meaning, security, difficult defects and final acceptance.
- Use Luna or deterministic scripts for bounded structural checks, with DeepSeek and GLM reserved for simple tasks.
- Require short worker briefs with inputs, ownership, checks, limits and a stop condition; keep implementation in assigned worktrees.
- Replace repeated status scans with completion events and a single deterministic reconciliation check.
- Add compact evidence targets, per-task usage records and token ceilings.
- Reduce startup context and require session-detail archives before context compaction.
