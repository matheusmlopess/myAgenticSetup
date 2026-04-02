# Claude Code Enterprise Guide

This repo is organized for multi-surface SaaS development.

## Start Sequence

1. Read `ai/context/project.md`.
2. Read `ai/standards/engineering.md`.
3. Read `ai/standards/security.md` for auth, tenant, and data handling rules.
4. Load a matching role from `.claude/agents/` when the task is specialized.

## Claude-Specific Files

- `.claude/agents/`: Claude subagents
- `.claude/skills/`: Claude project skills and reusable slash-invokable capabilities
- `.claude/commands/`: optional legacy command files
- `.mcp.json`: Claude project MCP definitions

Prefer `.claude/skills/` over `.claude/commands/` for anything non-trivial. Keep the shared layer in `ai/` as the source material those skills and agents reference.
