# Enterprise Agent Operating Guide

Read `ai/context/project.md` and `ai/standards/engineering.md` before changing code.

## Operating Priorities

1. Preserve tenant isolation, auth boundaries, and billing correctness.
2. Keep app boundaries explicit across `apps/` and `packages/`.
3. Update tests and docs alongside behavior changes.
4. Record structural decisions in `docs/adr/`.
5. Record security-sensitive changes in `docs/security/` when relevant.

## Repo Model

- `apps/` contains deployable surfaces.
- `packages/` contains reusable platform capabilities.
- `infra/` contains delivery and runtime infrastructure.
- `docs/` contains product, architecture, operations, and governance material.
- `ai/` contains the shared AI operating layer for both Codex and Claude.
- Codex runtime-installed skills, when used, live outside the repo under `~/.codex/skills/`.
- Codex runtime-installed plugins, when used, live outside the repo under `~/.codex/plugins/`.

## Working Rules

- Do not inline secrets or credentials.
- Prefer adapters around external providers.
- Keep policy, auth, and billing logic centralized in dedicated packages.
- Treat migrations and permissions changes as high-risk work.
