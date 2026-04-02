# Agent Operating Guide

This repository is structured for autonomous coding agents.

## Priority Order

1. Read `ai/context/project.md` before making decisions.
2. Follow `ai/standards/engineering.md` for implementation rules.
3. Prefer changes inside `apps/` and `packages/` over ad hoc top-level files.
4. Record major design decisions in `docs/adr/`.
5. Add or update tests in `tests/` or the relevant app package before closing work.

## Shared Conventions

- Product requirements live in `docs/product/`.
- Architecture and integration boundaries live in `docs/architecture/`.
- Reusable execution playbooks live in `ai/commands/`.
- Reusable role definitions live in `ai/agents/`.
- Project-local workflow guides live in `ai/playbooks/`.
- Codex runtime-installed skills, when used, live outside the repo under `~/.codex/skills/`.
- Codex runtime-installed plugins, when used, live outside the repo under `~/.codex/plugins/`.
- Operational scripts live in `scripts/ai/`.

## Working Rules

- Do not hardcode secrets.
- Keep business logic out of UI-only packages.
- Prefer small, reviewable changes.
- When changing behavior, update docs and tests in the same pass.
