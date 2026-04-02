# Engineering Standards

## System Boundaries

- Deployable systems live under `apps/`.
- Shared platform logic lives under `packages/`.
- Infrastructure definitions live under `infra/`.
- Durable design decisions belong in `docs/adr/`.

## Code Rules

- Add or update tests for changed behavior.
- Keep public contracts typed and explicit.
- Centralize policy, auth, and billing logic.
- Hide external provider details behind adapters.

## Delivery Rules

- Ship vertical slices with docs and tests.
- Add runbook updates for operationally meaningful changes.
- Document migrations and rollout ordering.
