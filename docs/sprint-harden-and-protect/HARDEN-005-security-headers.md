# HARDEN-005: Add HTTP Security Headers

## Priority: P1 — High
## Size: Small (30 min - 1 hour)
## Theme: Browser & Transport Security

---

## Problem Statement
The API sets no custom security headers. `config/application.rb` has no middleware for headers, and `config/environments/production.rb` only has `force_ssl`. API responses lack protections against clickjacking, MIME-sniffing, and browser API abuse.

## Files to Create/Modify

| File | Action |
|------|--------|
| `config/initializers/security_headers.rb` | Create — middleware to inject headers |
| `spec/requests/security_headers_spec.rb` | Create — verify headers on a response |

## Implementation Steps

### Step 1: Create `config/initializers/security_headers.rb`
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Headers do |headers|
  headers["X-Frame-Options"]        = "DENY"
  headers["X-Content-Type-Options"] = "nosniff"
  headers["Referrer-Policy"]        = "strict-origin-when-cross-origin"
  headers["Permissions-Policy"]     = "camera=(), microphone=(), geolocation=()"
  headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
end
```

**Alternative approach** (simpler, no custom middleware): Add headers directly in `BaseController`:
```ruby
# app/controllers/api/v1/base_controller.rb
after_action :set_security_headers

private

def set_security_headers
  response.headers["X-Frame-Options"]           = "DENY"
  response.headers["X-Content-Type-Options"]    = "nosniff"
  response.headers["Referrer-Policy"]           = "strict-origin-when-cross-origin"
  response.headers["Permissions-Policy"]        = "camera=(), microphone=(), geolocation=()"
  response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
end
```
**Recommendation**: Use the `BaseController` approach — it's simpler, testable, and scoped only to API responses (not Devise/Warden responses).

### Step 2: Write request spec
```ruby
# spec/requests/security_headers_spec.rb
RSpec.describe "Security Headers", type: :request do
  it "includes security headers in API responses" do
    user = create(:user)
    sign_in(user) # or however auth helper works
    get "/api/v1/clients"

    expect(response.headers["X-Frame-Options"]).to eq("DENY")
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
    expect(response.headers["Permissions-Policy"]).to eq("camera=(), microphone=(), geolocation=()")
    expect(response.headers["Strict-Transport-Security"]).to eq("max-age=31536000; includeSubDomains")
  end
end
```

## Acceptance Criteria
1. All 5 headers are present in every API response
2. Headers are set in `BaseController` (or middleware — pick one approach)
3. A request spec verifies header presence
4. `bundle exec rspec` passes

## Risks
- **Low risk**: Additive headers, no behavior change
- **CSP**: Intentionally omitted — complex for APIs, not needed for API-only app

## Dependencies
- None

## Out of Scope
- Content-Security-Policy
- CORS changes (already configured in `config/initializers/cors.rb`)
