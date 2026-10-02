# Changelog

## Unreleased

- Add `lane/secret-scan.sh` (gitleaks over the pushed range) as the required pre-push gate; `install.sh --check` reports gitleaks.
- Turn the per-task flow into a checklist with loop-backs for failed reconciliation, review, and post-integration checks.
- Define safe worktree and branch removal (no `--force`; `branch -d` before `-D`).
- Write the session-detail archive to `$S/sessions/` before compaction, since session-detail only prints in Claude Code.

## 0.1.0 — 2026-10-01

Initial versioned release of the refreshed lanes workflow.

- Recommend Codex Sol at medium effort and Claude Opus 5.5 at medium effort for orchestration; reserve high effort for legal meaning, security, difficult defects and final acceptance.
- Use Luna or deterministic scripts for bounded structural checks, with DeepSeek and GLM reserved for simple tasks.
- Require short worker briefs with inputs, ownership, checks, limits and a stop condition; keep implementation in assigned worktrees.
- Replace repeated status scans with completion events and a single deterministic reconciliation check.
- Add compact evidence targets, per-task usage records and token ceilings.
- Reduce startup context and require session-detail archives before context compaction.
