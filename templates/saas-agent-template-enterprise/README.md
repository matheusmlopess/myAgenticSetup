# Enterprise SaaS Agent Template

This is the heavier version of the starter for multi-team SaaS products that need stronger separation between product apps, platform services, compliance artifacts, and agent workflows.

## When To Use This Version

Use this template when you expect:

- multiple frontend surfaces such as customer app and admin app
- a dedicated API and background worker layer
- shared platform packages for auth, billing, analytics, notifications, and SDKs
- formal runbooks, ADRs, security notes, and compliance documentation
- specialized agents for architecture, platform, release, and security work

If the product is still small, this version is too much structure. Use the lighter template instead.

## Layout

```text
saas-agent-template-enterprise/
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

## Design Rule

`ai/` is still the shared source of truth. Claude gets project-native folders in `.claude/`. Codex is documented by the repo but its installed skills and plugins stay outside the project.

## Tool Boundary

This template is intentionally split between shared docs and project-native Claude folders.

- Codex repo rules: `AGENTS.md`
- Codex user skills: `~/.codex/skills/<skill>/SKILL.md`
- Codex user plugins: `~/.codex/plugins/<plugin>/`
- Claude project memory: `CLAUDE.md`
- Claude project skills: `.claude/skills/<skill>/SKILL.md`
- Claude project subagents: `.claude/agents/*.md`
- Claude project MCP: `.mcp.json`

`ai/` is not a native skill-discovery location for either tool. It exists to hold shared context and standards that both tools can read.

## Enterprise Boundaries

- `apps/web`: customer-facing app
- `apps/admin`: internal operations and support app
- `apps/api`: core backend API
- `apps/gateway`: edge or BFF layer when needed
- `apps/worker`: async processing and integrations
- `packages/auth`: identity and permission logic
- `packages/billing`: plans, invoicing, subscriptions
- `packages/analytics`: event contracts and metric helpers
- `packages/notifications`: email, SMS, and workflow messaging
- `packages/sdk`: typed API clients for internal and external consumers
- `infra/kubernetes`: deployment manifests or Helm charts
- `infra/monitoring`: dashboards, alerts, and observability config
- `docs/security`: threat models, control notes, and exception records
- `docs/compliance`: audit evidence index, policy references, and controls mapping
- `docs/incident-response`: incident templates and playbooks

## Enterprise Agent Model

- shared rules in `AGENTS.md`
- shared project context in `ai/context/`
- shared engineering and security standards in `ai/standards/`
- shared role definitions in `ai/agents/`
- Claude-ready wrappers in `.claude/`
- optional Codex notes in `.codex/`

## Codex Reality Check

Codex is outside project scope in this layout.

- User-installed marketplace skills generally install outside the repo, typically under `~/.codex/skills`
- User-installed plugins generally install under `~/.codex/plugins` and may also be listed in `~/.agents/plugins/marketplace.json`
- The project should only provide Codex instructions and context through `AGENTS.md`, `ai/`, and optional `.codex/` examples

If you need reusable in-repo capability definitions, prefer Claude project skills in `.claude/skills/` or shared docs in `ai/`.

## Claude Reality Check

Claude still supports `.claude/commands/`, but current docs recommend skills because they support supporting files and are automatically discoverable.

- Prefer `.claude/skills/` for reusable project capabilities
- Use `.claude/agents/` for specialist subagents
- Keep `.claude/commands/` only for simple legacy-style prompts if you really need explicit slash-command files

## First Setup

1. Replace placeholders in `ai/context/project.md`.
2. Remove apps and packages you do not need.
3. Fill in `docs/security/` and `docs/compliance/` only if they are real requirements.
4. Register approved MCP servers in `ai/mcp/catalog.md`.
5. Put repo-native Claude skills in `.claude/skills/`.
6. Copy MCP snippets from `.mcp.json` and `.codex/config.toml.example` into your actual tool configuration as needed.
