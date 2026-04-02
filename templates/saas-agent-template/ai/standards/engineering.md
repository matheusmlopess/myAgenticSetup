# Engineering Standards

## Architecture

- Keep deployable surfaces in `apps/`.
- Keep reusable code in `packages/`.
- Use `docs/adr/` for decisions that change interfaces, data models, or deployment shape.

## Code Quality

- Add tests for changed behavior.
- Prefer explicit types at system boundaries.
- Isolate external integrations behind adapters.
- Keep configuration in env vars, never inline secrets.

## Delivery

- Ship vertical slices instead of broad unfinished scaffolding.
- Update docs when setup, behavior, or operating assumptions change.
- Use `scripts/ai/` for repetitive local workflows.
