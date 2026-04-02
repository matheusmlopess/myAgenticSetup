# Claude Code Guide

Use this file as the Claude Code repo entrypoint.

## Start Here

1. Read `ai/context/project.md`.
2. Read `ai/standards/engineering.md`.
3. If the task is role-specific, load the matching file in `.claude/agents/`.
4. If the task maps to an existing reusable capability, prefer `.claude/skills/`.
5. If the task maps to an existing playbook, use `.claude/commands/` or `ai/commands/`.

## Repo Expectations

- Main product surfaces live in `apps/`.
- Shared libraries live in `packages/`.
- Cross-cutting guidance lives in `ai/`.
- Repo-local workflow guides live in `ai/playbooks/`.
- Architecture records live in `docs/adr/`.
- MCP servers for this repo are declared in `.mcp.json`.

## Claude-Specific Structure

- `.claude/agents/`: Claude subagents specialized by function.
- `.claude/skills/`: Claude project skills.
- `.claude/commands/`: optional slash command prompt files.
- `.mcp.json`: Claude project MCP config.

When a task does not require a Claude-specific wrapper, prefer the shared definitions under `ai/`. For reusable capabilities, prefer `.claude/skills/` over `.claude/commands/`.
