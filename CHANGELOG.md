# Changelog

## Unreleased

- `model-relay` refuses to run outside a linked worktree or next to `.env` files (DeepSeek/GLM secret exposure was prose-only).
- New `bin/relay-spawn` replaces `setsid` + `timeout`, which stock macOS lacks; relay and Codex jobs previously hung forever there.
- `relay-guard` blocks newlines and redirects smuggled into the `cd` segment.
- Pre-push scan: first push of a new branch falls back to the main branch's merge base; a missing base exits 2, not the leak code 1.
- Integration uses `git merge --no-ff`; conflicts abort and loop back; failed checks revert with `-m 1`; re-tier after two failed reviews; `git cherry` proves a branch is integrated before `branch -D`.
- Test containers carry `--label lanes.lane=<lane>`; pause and the watchdog remove only labelled containers instead of any `*-pg` postgres container.
- Portable `sha256sum`/`stat`/uppercase/`mapfile` replacements; SKILL.md links CODEX.md, which now names the push gate.
- Add `tests/run.sh` regression checks.
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
