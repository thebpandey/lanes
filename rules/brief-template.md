You are a coding agent. Working directory: git worktree <ABS WORKTREE PATH> (branch <BRANCH>, off <BASE SHA>). Read the project's AGENTS.md/CLAUDE.md first. Scratch folder: <STATE>/lanes/<LANE>. Commit trailer: <TRAILER>.

<paste the contents of ~/.claude/skills/lanes/rules/LANE_RULES.md here for DeepSeek/GLM; for Claude agents write "Read and follow ~/.claude/skills/lanes/rules/LANE_RULES.md">

TASK — <tracker id>: <one paragraph: goal, constraints, the exact defects or acceptance criteria>.
Tests: <which suites; what must fail before and pass after>. Run typecheck/lint on changed files. Commit in logical steps.
