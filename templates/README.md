```text
SYSTEM / USER LEVEL

~/.codex/
├── config.toml
├── skills/
│   ├── some-marketplace-skill/
│   │   └── SKILL.md
│   └── ...
├── plugins/
│   ├── some-plugin/
│   │   ├── .codex-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   └── ...
└── ...

~/.agents/
└── plugins/
    └── marketplace.json

PROJECT LEVEL

your-saas/
├── AGENTS.md
├── CLAUDE.md
├── .mcp.json
├── .claude/
│   ├── skills/
│   │   ├── saas-architect/
│   │   │   └── SKILL.md
│   │   └── release-manager/
│   │       └── SKILL.md
│   ├── agents/
│   │   ├── product-architect.md
│   │   ├── backend-engineer.md
│   │   └── frontend-engineer.md
│   └── commands/
│       ├── plan.md
│       ├── review.md
│       └── ship.md
├── .codex/
│   ├── config.toml.example
│   ├── prompts/
│   └── mcp/
├── ai/
│   ├── context/
│   ├── standards/
│   ├── agents/
│   ├── commands/
│   ├── playbooks/
│   └── mcp/
├── apps/
│   ├── web/
│   ├── api/
│   └── worker/
├── packages/
│   ├── ui/
│   ├── database/
│   └── config/
├── infra/
│   ├── docker/
│   └── terraform/
├── docs/
│   ├── adr/
│   ├── architecture/
│   ├── product/
│   ├── runbooks/
│   └── evals/
├── scripts/
│   └── ai/
├── tests/
│   ├── e2e/
│   ├── integration/
│   └── contract/
└── .github/
    └── workflows/
```

## Folder Explanations

### System / User Level

- `~/.codex/config.toml`: User-level Codex configuration for local defaults and runtime behavior.
- `~/.codex/skills/`: Installed Codex skills available across projects.
- `~/.codex/plugins/`: Installed Codex plugins, including their manifest and any plugin-scoped skills.
- `~/.agents/plugins/marketplace.json`: Marketplace registry and ordering metadata for plugins.

### Project Level

- `AGENTS.md`: Repo-specific instructions for Codex and other coding agents.
- `CLAUDE.md`: Repo-specific memory and operating guidance for Claude.
- `.mcp.json`: Project MCP server configuration and connector definitions.
- `.claude/skills/`: Claude project-local reusable skills.
- `.claude/agents/`: Claude subagent role definitions.
- `.claude/commands/`: Claude slash-command prompt files such as `plan`, `review`, and `ship`.
- `.codex/config.toml.example`: Example Codex configuration to copy into user-level setup.
- `.codex/prompts/`: Codex prompt or command examples meant to live alongside the project.
- `.codex/mcp/`: Codex MCP examples or reference snippets for project setup.
- `ai/context/`: Shared project context, constraints, and domain background for agents.
- `ai/standards/`: Engineering, product, and security standards agents should follow.
- `ai/agents/`: Shared agent definitions or role docs that are tool-agnostic.
- `ai/commands/`: Shared command prompts and workflows for planning, review, and shipping.
- `ai/playbooks/`: Repeatable operational playbooks for common delivery tasks.
- `ai/mcp/`: Shared MCP catalog or integration notes for the project.
- `apps/`: Deployable application surfaces such as web, API, and worker services.
- `packages/`: Shared internal libraries such as UI, database, and config packages.
- `infra/`: Infrastructure code such as Docker and Terraform definitions.
- `docs/`: Human-facing documentation including architecture, ADRs, runbooks, product notes, and evals.
- `scripts/ai/`: Automation scripts used by agent workflows.
- `tests/`: Higher-level test suites such as end-to-end, integration, and contract coverage.
- `.github/workflows/`: GitHub Actions automation and CI/CD workflows.
