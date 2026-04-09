# HARDEN-002: Add API Rate Limiting

## Priority: P0 — Critical
## Size: Medium (3-4 hours)
## Theme: DDoS & Abuse Protection

---

## Problem Statement
The API has zero rate limiting. Any IP can send unlimited requests to login, signup, invoice creation, and AFIP endpoints. This enables brute-force attacks, resource exhaustion, and risks getting the CUIT blocked by AFIP (which has undocumented rate limits).

## Files to Create/Modify

| File | Action |
|------|--------|
| `Gemfile` | Add `gem 'rack-attack'` |
| `config/initializers/rack_attack.rb` | Create — all throttle/blocklist rules |
| `config/application.rb` | Register `Rack::Attack` middleware (if needed) |
| `spec/requests/rate_limiting_spec.rb` | Create — verify throttle on login endpoint |

## Implementation Steps

### Step 1: Install rack-attack
Add to `Gemfile` (outside any group — it must run in production):
```ruby
gem 'rack-attack', '~> 6.7'
```
Run `bundle install`.

### Step 2: Create `config/initializers/rack_attack.rb`
```ruby
class Rack::Attack
  # Use Rails cache (Solid Cache) as the backing store
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # --- Throttles ---

  # General API: 100 req/min per IP
  throttle("req/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Login: 5 req/20s per email
  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/api/v1/auth/sign_in" && req.post?
      # Normalize email to prevent bypass via casing
      req.params.dig("user", "email")&.downcase&.strip
    end
  end

  # Signup: 3 req/min per IP
  throttle("signups/ip", limit: 3, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth" && req.post?
  end

  # AFIP submissions: 10 req/min per user (via JWT)
  throttle("afip/user", limit: 10, period: 1.minute) do |req|
    if req.path.match?(%r{/api/v1/(client_invoices|credit_notes)/\d+/send_to_arca}) && req.patch?
      # Extract user from JWT — use a lightweight decode, not full auth
      req.env["warden"]&.user&.id
    end
  end

  # Authenticated API: 300 req/min per user
  throttle("api/user", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/") && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  # --- Blocklists ---

  # Auto-ban IPs scanning for common exploit paths
  blocklist("malicious-scanners") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
      req.path.match?(%r{/(wp-admin|wp-login|\.env|phpmyadmin|phpinfo|cgi-bin|\.git)})
    end
  end

  # --- Response ---

  self.throttled_responder = lambda do |matched, _env, _data, _request|
    retry_after = (matched.first.last[:period] rescue 60)
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [{ error: { code: "rate_limited", message: "Too many requests. Retry after #{retry_after}s" } }.to_json]
    ]
  end
end

# Disable in test environment
Rack::Attack.enabled = !Rails.env.test?
```

### Step 3: Write request spec
Create `spec/requests/rate_limiting_spec.rb`:
- Test that 6th login attempt within 20s returns HTTP 429
- Test that the response body matches `{ "error": { "code": "rate_limited", ... } }`
- Test that `Retry-After` header is present
- Enable `Rack::Attack` temporarily in the test with `before { Rack::Attack.enabled = true }` / `after { Rack::Attack.enabled = false }`

## Acceptance Criteria
1. `rack-attack` gem is installed and configured in `config/initializers/rack_attack.rb`
2. All throttle rules from the table are implemented
3. Throttled requests return HTTP 429 with JSON `{ "error": { "code": "rate_limited", ... } }` and `Retry-After` header
4. Rate limiting uses Solid Cache (or MemoryStore) as backing store
5. Malicious path scanning triggers auto-ban after 3 attempts
6. Rate limiting is disabled in test environment (enabled only in specific rate-limit specs)
7. At least one request spec verifies throttle behavior on login

## Risks
- **Shared IPs**: Per-IP limit (100/min) is generous to avoid false positives behind NAT. Per-user limits handle authenticated abuse.
- **Cache dependency**: If cache is down, `Rack::Attack` should fail-open (allow requests through).
- **AFIP throttle**: The user-scoped AFIP throttle requires Warden to have already authenticated the user. If the middleware ordering doesn't provide this, fall back to IP-based throttling for AFIP endpoints.

## Dependencies
- None

## Out of Scope
- Cloudflare WAF rules
- IP allowlisting/blocklisting admin UI
