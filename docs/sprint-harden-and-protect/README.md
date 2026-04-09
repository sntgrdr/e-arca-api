# Sprint: Harden & Protect

## Sprint Goal
Close critical security vulnerabilities, establish authorization guardrails, and build a testing foundation before adding new features. This sprint protects user data, ensures AFIP compliance, and reduces operational risk.

## Why Now
The application handles sensitive financial data (invoices, tax IDs, AFIP certificates) and is integrated with Argentina's federal tax authority. Security gaps at this stage compound as the user base grows. Fixing them now is 10x cheaper than fixing them after an incident.

## Codebase Context

**Key architectural facts for implementers:**
- Rails 8.1 API-only app, PostgreSQL, Solid Queue for background jobs
- Auth: Devise + devise-jwt with JWT tokens (configured in `config/initializers/devise.rb:314-324`)
- Multi-tenancy: manual `where(user_id: current_user.id)` in every controller — no authorization framework
- Base controller: `app/controllers/api/v1/base_controller.rb` — all API controllers inherit from here
- AFIP integration: Production services at `app/services/invoices/production/`, dev at `app/services/invoices/development/`
- 10 controllers, 15 services, 2 jobs, 13 models
- CI: only brakeman + rubocop (no tests running, no dependency scanning)

**Gems NOT yet installed** (needed by this sprint): `pundit`, `rack-attack`, `paper_trail`, `discard`, `bundler-audit`, `strong_migrations`, `webmock`

## Sprint Structure

| Priority | Tickets | Theme | Estimated Hours |
|----------|---------|-------|-----------------|
| P0 — Critical | 4 tickets | Security vulnerabilities | ~10-14h |
| P1 — High | 7 tickets | Hardening & resilience | ~10-14h |
| P2 — Important | 6 tickets | Tests, audit, protection | ~18-24h |

## Dependency Graph

```
HARDEN-006 (error handling) → HARDEN-007 (sanitize errors)
HARDEN-010 (remove constantize) → HARDEN-011 (idempotency)
HARDEN-004 (Pundit) ←→ HARDEN-013 (multi-tenancy tests)
HARDEN-011 (idempotency) → HARDEN-015 (protect invoices)
HARDEN-012 (ARCA tests) → HARDEN-017 (filter/job tests)
```

All other tickets are independent and can be parallelized.

## Tickets Index

### P0 — Critical (Do First)
1. [HARDEN-001: Secure JWT Secret Management](./HARDEN-001-secure-jwt-secret.md) — Move JWT secret to Rails credentials, fail on missing
2. [HARDEN-002: Add API Rate Limiting](./HARDEN-002-rate-limiting.md) — Install rack-attack with per-IP/user/endpoint throttles
3. [HARDEN-003: Fix Production SSL Cipher Weakness](./HARDEN-003-fix-ssl-ciphers.md) — Remove `@SECLEVEL=0` and `verify: false` from 4 AFIP service files
4. [HARDEN-004: Implement Authorization Layer](./HARDEN-004-authorization-layer.md) — Install Pundit, create 8 policies, enforce on all controllers

### P1 — High (Do Second)
5. [HARDEN-005: Add HTTP Security Headers](./HARDEN-005-security-headers.md) — 5 security headers via BaseController after_action
6. [HARDEN-006: Standardize Error Handling](./HARDEN-006-error-handling.md) — Fix 4 bare `rescue => e` in controllers/jobs/services
7. [HARDEN-007: Sanitize API Error Responses](./HARDEN-007-sanitize-errors.md) — Rewrite BaseController rescue_from blocks, stop leaking internals
8. [HARDEN-008: Add Dependency Security Scanning to CI](./HARDEN-008-dependency-scanning.md) — Add bundler-audit + strong_migrations + rspec to CI
9. [HARDEN-009: Strengthen Password Policy](./HARDEN-009-password-policy.md) — 12-char minimum, Devise Lockable (5 attempts, 15min)
10. [HARDEN-010: Remove Dynamic Class Loading](./HARDEN-010-remove-constantize.md) — Replace 2 `constantize` calls with explicit conditional
11. [HARDEN-011: Add AFIP Submission Idempotency](./HARDEN-011-afip-idempotency.md) — Add `afip_status` enum, `with_lock`, status transitions

### P2 — Important (Do Third)
12. [HARDEN-012: Test Coverage for ARCA Services](./HARDEN-012-test-arca-services.md) — WebMock-based tests for 15 AFIP service classes
13. [HARDEN-013: Test Coverage for Multi-Tenancy](./HARDEN-013-test-multi-tenancy.md) — Cross-user access tests for all 8 resource controllers
14. [HARDEN-014: Add Invoice Audit Trail](./HARDEN-014-audit-trail.md) — PaperTrail on invoices/credit notes/clients + history API
15. [HARDEN-015: Protect AFIP-Authorized Invoices from Deletion](./HARDEN-015-protect-invoices.md) — Discard gem for soft-delete, block deletion of CAE invoices
16. [HARDEN-016: Add Background Job Resilience](./HARDEN-016-job-resilience.md) — retry_on, idempotent bulk creation, granular failure tracking
17. [HARDEN-017: Test Coverage for Filter Services and Jobs](./HARDEN-017-test-filters-jobs.md) — Unit tests for 3 filter services + 2 background jobs
