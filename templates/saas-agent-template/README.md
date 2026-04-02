# SaaS Agent Template

Starter structure for a new SaaS project that is meant to work well with both Codex CLI and Claude Code.

The template uses three layers:

1. `ai/` is the shared source of truth for project context, standards, reusable agent roles, and project-local playbooks.
2. `.claude/` contains Claude Code native assets such as project skills and subagents.
3. `AGENTS.md` plus optional `.codex/` notes define how Codex should work with the repo, while Codex-installed skills and plugins stay outside the project.

## Recommended Layout

```text
saas-agent-template/
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

## What Goes Where

- `AGENTS.md`: shared repo-wide operating rules for coding agents.
- `CLAUDE.md`: Claude Code specific workflow and repo entrypoint.
- `.mcp.json`: project MCP config for Claude Code.
- `.codex/config.toml.example`: example Codex MCP/profile config you can copy into your user config as needed.
- `ai/context/`: product, business, and technical context that both tools should read.
- `ai/standards/`: coding standards, architecture rules, release rules, and security boundaries.
- `ai/agents/`: vendor-neutral role definitions that can be mirrored into tool-specific agent files.
- `ai/commands/`: reusable task playbooks such as planning, code review, and release prep.
- `ai/playbooks/`: repo-owned workflow docs and capability guides that both tools can read as project context.
- `apps/`: deployable apps such as web, api, and workers.
- `packages/`: shared libraries such as UI, SDK, DB, and tooling config.
- `infra/`: Docker, Terraform, and environment provisioning.
- `docs/`: ADRs, architecture notes, product docs, and runbooks.
- `scripts/ai/`: shell wrappers for repetitive workflows that both CLIs can execute.
- `tests/`: cross-app test suites.

## Tooling Notes

- Claude Code supports project memory through `CLAUDE.md`, project MCP via `.mcp.json`, project skills in `.claude/skills/`, and subagents in `.claude/agents/`.
- Codex CLI should use `AGENTS.md` plus the shared docs in `ai/`.
- `.codex/` is optional helper material for config snippets and human-authored prompt recipes. It is not the runtime install location for Codex skills or plugins.
- `ai/playbooks/` is shared repo documentation. It is not a native install location for either Codex or Claude runtime skills.
- Keep secrets out of repo config. Store placeholders in `.env.example` and read real values from environment variables.

## Marketplace And Import Reality

- Codex marketplace-installed skills usually end up outside the repo, typically under `~/.codex/skills`.
- Codex marketplace-installed plugins usually live under `~/.codex/plugins` and may also be listed in `~/.agents/plugins/marketplace.json`.
- Claude plugin-installed Skills come from the installed plugin, while project-native Claude Skills live in `.claude/skills/`.
- In this template, Codex capabilities are intentionally outside repo scope. The project only documents Codex usage through `AGENTS.md`, shared docs in `ai/`, and optional `.codex/` examples.
- If you need a reusable in-repo capability, prefer `.claude/skills/` for Claude and `ai/playbooks/` for shared documentation.

## Suggested Docs To Add Early

- `docs/evals/README.md`: AI eval strategy, scoring design, and ASCII workflow drafts for prompt, retrieval, and model regressions.

## First Steps After Copying This Template

1. Rename the project and replace all placeholder text.
2. Fill in `ai/context/project.md` with product scope and domain language.
3. Update `AGENTS.md` and `CLAUDE.md` with your team rules.
4. Add or remove apps under `apps/` based on your product shape.
5. Add Claude project skills in `.claude/skills/` when you need reusable in-repo capabilities.
6. Configure MCP servers in `.mcp.json` and `.codex/config.toml.example`.
