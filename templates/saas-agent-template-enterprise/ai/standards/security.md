# Security Standards

## High-Risk Areas

- authentication and session handling
- authorization and permissions
- tenant isolation
- billing and payment flows
- admin actions and support impersonation
- file upload and webhook ingestion

## Rules

- Never hardcode secrets.
- Validate auth and authorization at system boundaries.
- Keep privileged admin flows separate from end-user flows.
- Record threat-relevant design changes in `docs/security/`.
- Add security tests for auth, tenant, or input validation changes.
