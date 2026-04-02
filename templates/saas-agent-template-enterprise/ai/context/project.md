# Project Context

## Product Summary

Describe the product, customers, revenue model, and regulated or sensitive workflows here.

## Operating Model

- Customer segment:
- Buying motion:
- Contract model:
- Data sensitivity:
- Deployment model:

## Domain Language

- Workspace:
- Organization:
- User:
- Role:
- Subscription:
- Invoice:
- Event:

## Core Surfaces

- `apps/web`: customer product
- `apps/admin`: internal admin and support tooling
- `apps/api`: primary application backend
- `apps/gateway`: edge aggregation or BFF layer
- `apps/worker`: background jobs and provider syncs

## Shared Platform Packages

- `packages/auth`
- `packages/billing`
- `packages/analytics`
- `packages/notifications`
- `packages/database`
- `packages/sdk`

## Current Constraints

- Prefer explicit ownership and package boundaries.
- Avoid cross-app business logic duplication.
- Treat tenant and billing assumptions as durable decisions.
