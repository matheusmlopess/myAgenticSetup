# SaaS Agent Template: CLI Focused

This variant keeps the SaaS repo skeleton shallow and expands only the AI-facing folders for Claude Code and Codex CLI.

Use it when you want:

- full project-native Claude structure
- repo-visible Codex notes and prompt scaffolding
- minimal noise in app, package, infra, and docs folders

## Layout

```text
templates/saas-agent-template-cli-focused
├── AGENTS.md
├── CLAUDE.md
├── .mcp.json
├── .codex/
├── .claude/
├── ai/
├── apps/
├── packages/
├── infra/
├── docs/
├── scripts/
├── tests/
└── .github/
```

## Rule

- Codex runtime skills and plugins stay outside the repo
- Claude project skills and agents stay inside the repo
- shared project context lives in `ai/`
