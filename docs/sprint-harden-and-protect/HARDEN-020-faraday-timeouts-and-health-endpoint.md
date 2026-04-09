# HARDEN-020: Add Faraday Timeouts to AFIP Services + Health Endpoint

## Priority: P1 — High
## Size: Small (1-2 hours)
## Theme: Resilience

---

## Problem Statement

### 1. No timeouts on AFIP HTTP calls
All 5 Faraday connections to AFIP have no timeout configured. AFIP's infrastructure is known to be unreliable — it goes down regularly, responds slowly during peak hours, and occasionally hangs indefinitely. Without timeouts, a hung AFIP call will hold a Puma thread open until the OS TCP timeout (~2 minutes), blocking all other requests on that thread.

### Affected files

| File | Faraday call |
|------|-------------|
| `app/services/invoices/production/send_to_arca_service.rb:43` | `Faraday.new(url: URL, ssl: { verify: true })` |
| `app/services/invoices/production/auth_with_arca_service.rb:87` | `Faraday.new(url: URL, ssl: { verify: true })` |
| `app/services/invoices/production/get_last_invoice_service.rb:34` | `Faraday.new(url: URL, ssl: { verify: true })` |
| `app/services/invoices/development/send_to_arca_service.rb:39` | `Faraday.new(...)` |
| `app/services/invoices/development/auth_with_arca_service.rb:58` | `Faraday.new(url: URL, ssl: { verify: true })` |

### 2. No health endpoint
The app has no `GET /api/v1/health` endpoint. This is required for:
- **Kamal** — health checks before declaring a deploy successful
- **UptimeRobot** — external uptime monitoring
- **Docker** — `HEALTHCHECK` instruction

Rails provides `GET /up` (added by the generator), but it doesn't check DB connectivity. A proper health endpoint should confirm the database is reachable.

## Desired Behavior

### Faraday timeouts
Every AFIP Faraday connection should set:
- `request.timeout = 20` — total request time limit
- `request.open_timeout = 5` — connection establishment limit

```ruby
conn = Faraday.new(url: URL, ssl: { verify: true }) do |f|
  f.options.timeout      = 20
  f.options.open_timeout = 5
  f.adapter :net_http
end
```

When AFIP times out, `Faraday::TimeoutError` or `Faraday::ConnectionFailed` is raised. The existing `rescue StandardError => e` in each service's caller will catch it, set `afip_status: :rejected`, and return `{ success: false, errors: [e.message] }` — no change needed to error handling.

### Health endpoint

```ruby
# config/routes.rb
get 'api/v1/health', to: 'api/v1/health#show'
```

```ruby
# app/controllers/api/v1/health_controller.rb
module Api
  module V1
    class HealthController < ActionController::API
      def show
        ActiveRecord::Base.connection.execute('SELECT 1')
        render json: { status: 'ok', timestamp: Time.zone.now.iso8601 }
      rescue StandardError => e
        render json: { status: 'error', message: e.message }, status: :service_unavailable
      end
    end
  end
end
```

The health endpoint must be **unauthenticated** — Kamal and UptimeRobot hit it without credentials.

## Files to Create / Modify

| File | Action |
|------|--------|
| `app/services/invoices/production/send_to_arca_service.rb` | Add timeout options to Faraday.new |
| `app/services/invoices/production/auth_with_arca_service.rb` | Add timeout options to Faraday.new |
| `app/services/invoices/production/get_last_invoice_service.rb` | Add timeout options to Faraday.new |
| `app/services/invoices/development/send_to_arca_service.rb` | Add timeout options to Faraday.new |
| `app/services/invoices/development/auth_with_arca_service.rb` | Add timeout options to Faraday.new |
| `app/controllers/api/v1/health_controller.rb` | Create — DB check, unauthenticated |
| `config/routes.rb` | Add `get 'api/v1/health'` outside the authenticated namespace |

## Acceptance Criteria
1. All 5 Faraday connections have `timeout: 20` and `open_timeout: 5`
2. `GET /api/v1/health` returns `{ status: 'ok' }` with HTTP 200 when DB is up
3. `GET /api/v1/health` returns `{ status: 'error' }` with HTTP 503 when DB is down
4. Health endpoint requires no authentication (no JWT, no cookie)
5. Existing AFIP service specs still pass (WebMock stubs remain valid)
6. `bundle exec rspec` passes

## Out of Scope
- Circuit breaker (`circuitbox` gem) — tracked separately
- AFIP-specific retry logic — covered by job resilience (HARDEN-016)
- Response time metrics / APM

## RICE Score
- Reach: 100% of AFIP calls + deployment infrastructure
- Impact: 2 (high — prevents thread starvation, enables monitoring)
- Confidence: 100%
- Effort: 0.25 person-weeks
- **Score: (100 × 2 × 1.0) / 0.25 = 800**
