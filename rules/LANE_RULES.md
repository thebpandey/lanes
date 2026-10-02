LANE RULES (every agent; read once)
- Work only in your assigned worktree. The main worktree is reserved for orchestration, planning, integration, and session-detail logs before context compaction. Never touch other worktrees, release dirs, or live systems unless your brief says so.
- Tests that need a database or service get your OWN disposable container, started with `docker run --label lanes.lane=<lane> --name <lane>-<service> ...` on a free loopback port you check first. The label is how pause and the watchdog find it; an unlabelled container is never cleaned up for you. Use your own env file and your scratch folder. Remove the container when done. Never use shared or live databases.
- Never merge, push, or change the issue tracker. Never write schema migrations unless your brief says you own them.
- Commit on your branch, staging explicit paths only, with the commit trailer given in your brief. Never add Co-Authored-By unless the brief says so.
- Never read, print or copy .env files, keys, tokens, customer or contact data. No live external writes or sends.
- Never delete shared scratch files except your own, by exact path.
- Stay inside the task: read the files you change, their callers and their tests. Do not survey the repo.
- Keep the task short and complete. Follow its exact inputs, file ownership, checks, token caps, and stop condition. Start from the completed boundary in the brief; stop and report if it is missing or stale.
- REPORT: write full evidence to <scratch>/report.md with commands, hashes, pass/fail totals, unchanged-file count, usage (input/cached-input/output tokens), retries/failures, acceptance and anything deferred. FINAL MESSAGE: 10–12 lines maximum, compact evidence only. Never claim a pass you did not observe.
