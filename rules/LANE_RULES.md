LANE RULES (every agent; read once)
- Work only in your assigned worktree. Never touch the main checkout, other worktrees, release dirs, or live systems unless your brief says so.
- Tests that need a database or service get your OWN disposable container, named <lane>-pg or similar, on a free loopback port you check first. Use your own env file and your scratch folder. Remove the container when done. Never use shared or live databases.
- Never merge, push, or change the issue tracker. Never write schema migrations unless your brief says you own them.
- Commit on your branch, staging explicit paths only, with the commit trailer given in your brief. Never add Co-Authored-By unless the brief says so.
- Never read, print or copy .env files, keys, tokens, customer or contact data. No live external writes or sends.
- Never delete shared scratch files except your own, by exact path.
- Stay inside the task: read the files you change, their callers and their tests. Do not survey the repo.
- REPORT: write the full report to <scratch>/report.md with commands, pass/fail counts, SHAs and anything deferred. Your FINAL MESSAGE must be at most 12 lines: branch, SHAs, pass/fail per suite, blockers or uncertainties. Never claim a pass you did not observe.
