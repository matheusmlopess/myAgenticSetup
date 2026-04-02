# Template Layout Rules

These templates follow one explicit boundary:

- Codex runtime capabilities are outside the project
- Claude project capabilities are inside the project

## Outside The Project

Codex-managed runtime assets belong in the user environment, not in the repository:

```text
~/.codex/
├── config.toml
├── skills/
└── plugins/

~/.agents/
└── plugins/
    └── marketplace.json
```

## Copy-Paste Starter Layout

```text
EXTERNAL TO THE PROJECT

~/.codex/
├── config.toml
├── skills/
└── plugins/

~/.agents/
└── plugins/
    └── marketplace.json

PROJECT

your-saas/
├── AGENTS.md
├── CLAUDE.md
├── .mcp.json
├── .codex/
│   ├── config.toml.example
│   ├── prompts/
│   └── mcp/
├── .claude/
│   ├── skills/
│   ├── agents/
│   └── commands/
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

## Inside The Project

The project repository keeps:

- `AGENTS.md` for Codex repo instructions
- `CLAUDE.md` for Claude repo memory
- `.claude/skills/` for Claude project-native reusable capabilities
- `.claude/agents/` for Claude subagents
- `.mcp.json` for Claude project MCP
- `ai/` for shared context, standards, and playbooks both tools can read
- optional `.codex/` examples for config snippets and prompt recipes

This keeps the repo portable without pretending Codex skills and plugins are repo-installed assets.

## Small Template Tree

```text
templates/saas-agent-template
├── AGENTS.md
├── CLAUDE.md
├── .mcp.json
├── .codex/
│   ├── README.md
│   ├── agents/
│   ├── config.toml.example
│   ├── mcp/
│   └── prompts/
├── .claude/
│   ├── agents/
│   ├── commands/
│   └── skills/
├── ai/
│   ├── README.md
│   ├── agents/
│   ├── commands/
│   ├── context/
│   ├── mcp/
│   ├── playbooks/
│   └── standards/
├── apps/
│   ├── README.md
│   ├── api/
│   ├── web/
│   └── worker/
├── packages/
│   ├── README.md
│   ├── config/
│   ├── database/
│   └── ui/
├── infra/
│   ├── README.md
│   ├── docker/
│   └── terraform/
├── docs/
│   ├── README.md
│   ├── adr/
│   ├── architecture/
│   ├── evals/
│   ├── product/
│   └── runbooks/
├── scripts/
│   └── ai/
├── tests/
│   ├── README.md
│   ├── contract/
│   ├── e2e/
│   └── integration/
└── .github/
    └── workflows/
```

## Enterprise Template Tree

```text
templates/saas-agent-template-enterprise
├── AGENTS.md
├── CLAUDE.md
├── .mcp.json
├── .codex/
│   ├── README.md
│   ├── agents/
│   ├── config.toml.example
│   ├── mcp/
│   └── prompts/
├── .claude/
│   ├── agents/
│   ├── commands/
│   └── skills/
├── ai/
│   ├── README.md
│   ├── agents/
│   ├── commands/
│   ├── context/
│   ├── mcp/
│   └── standards/
├── apps/
│   ├── README.md
│   ├── admin/
│   ├── api/
│   ├── gateway/
│   ├── web/
│   └── worker/
├── packages/
│   ├── README.md
│   ├── analytics/
│   ├── auth/
│   ├── billing/
│   ├── config/
│   ├── database/
│   ├── notifications/
│   ├── sdk/
│   └── ui/
├── infra/
│   ├── README.md
│   ├── docker/
│   ├── kubernetes/
│   ├── monitoring/
│   └── terraform/
├── docs/
│   ├── README.md
│   ├── adr/
│   ├── architecture/
│   ├── compliance/
│   ├── incident-response/
│   ├── product/
│   ├── runbooks/
│   └── security/
├── scripts/
│   ├── ai/
│   ├── ci/
│   └── ops/
├── tests/
│   ├── README.md
│   ├── contract/
│   ├── e2e/
│   ├── integration/
│   ├── performance/
│   └── security/
└── .github/
    └── workflows/
```
