# HARDEN-007: Sanitize API Error Responses

## Priority: P1 — High
## Size: Small (1-2 hours)
## Theme: Information Security

---

## Problem Statement
`app/controllers/api/v1/base_controller.rb` returns raw Ruby exception messages to the client:

```ruby
# Line 8-9
rescue_from ActiveRecord::RecordNotFound do |e|
  render json: { errors: [e.message] }, status: :not_found  # Leaks table/column names
end

# Line 12-13
rescue_from ActiveRecord::RecordInvalid do |e|
  render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
end
```

`RecordNotFound` messages contain: `"Couldn't find Client with 'id'=123 [WHERE "clients"."user_id" = $1]"` — revealing database schema, table names, and query structure.

Additionally, `profiles_controller.rb:29` returns `e.message` directly from any caught exception.

## Files to Modify

| File | Line(s) | Action |
|------|---------|--------|
| `app/controllers/api/v1/base_controller.rb` | 8-18 | Rewrite all `rescue_from` blocks with sanitized responses |
| `app/controllers/api/v1/profiles_controller.rb` | 28-29 | Sanitize error response |

## Implementation Steps

### Step 1: Rewrite `base_controller.rb` rescue blocks

```ruby
module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend

      before_action :authenticate_user!

      # --- Error handling ---

      rescue_from ActiveRecord::RecordNotFound do |e|
        Rails.logger.warn("[404] #{e.class}: #{e.message}")
        render json: { error: { code: "not_found", message: "Resource not found" } }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        Rails.logger.warn("[422] #{e.class}: #{e.message}")
        render json: { errors: e.record.errors.messages }, status: :unprocessable_entity
      end

      rescue_from Pagy::OverflowError do |_e|
        render json: { error: { code: "not_found", message: "Page not found" } }, status: :not_found
      end

      rescue_from StandardError do |e|
        Rails.logger.error("[500] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
        render json: { error: { code: "internal_error", message: "An unexpected error occurred" } }, status: :internal_server_error
      end

      # ... rest of controller unchanged
    end
  end
end
```

**Key changes**:
- `RecordNotFound`: Generic "Resource not found" — no table/column names
- `RecordInvalid`: Returns `errors.messages` (hash format: `{ "legal_name": ["can't be blank"] }`) instead of `full_messages` (array format) — structured for frontend consumption
- New `StandardError` catch-all: Returns generic 500, logs full backtrace server-side
- Every rescue logs the full error for debugging

### Step 2: Fix `profiles_controller.rb:28-29`
```ruby
# Before
rescue => e
  render json: { error: e.message }, status: :unprocessable_entity

# After
rescue StandardError => e
  Rails.logger.error("[ProfilesController#last_invoice] #{e.class}: #{e.message}")
  render json: { error: { code: "service_error", message: "Could not retrieve last invoice from AFIP" } }, status: :unprocessable_entity
```

### Step 3: Standardize the `render_errors` helper
Update the existing helper to use the new format:
```ruby
def render_errors(messages, status = :unprocessable_entity)
  render json: { errors: Array(messages) }, status: status
end
```
This can stay as-is since it's used for validation messages (which are safe to expose).

### Step 4: Write a request spec
```ruby
# spec/requests/error_handling_spec.rb
RSpec.describe "Error Handling", type: :request do
  it "returns generic message for 404" do
    get "/api/v1/clients/999999", headers: auth_headers(user)
    expect(response).to have_http_status(:not_found)
    body = JSON.parse(response.body)
    expect(body["error"]["code"]).to eq("not_found")
    expect(body["error"]["message"]).to eq("Resource not found")
    expect(response.body).not_to include("clients")  # No table names leaked
  end

  it "returns generic message for 500" do
    # Trigger an unhandled error (e.g., by stubbing a method to raise)
    allow(Client).to receive(:where).and_raise(RuntimeError, "DB connection lost")
    get "/api/v1/clients", headers: auth_headers(user)
    expect(response).to have_http_status(:internal_server_error)
    body = JSON.parse(response.body)
    expect(body["error"]["code"]).to eq("internal_error")
    expect(body["error"]["message"]).to eq("An unexpected error occurred")
    expect(response.body).not_to include("DB connection lost")
  end
end
```

## Error Response Format Reference

| Status | Format | Example |
|--------|--------|---------|
| 404 | `{ "error": { "code": "not_found", "message": "Resource not found" } }` | Missing resource |
| 403 | `{ "error": { "code": "forbidden", "message": "..." } }` | Pundit (HARDEN-004) |
| 422 (validation) | `{ "errors": { "field": ["message"] } }` | Model validation |
| 422 (business) | `{ "errors": ["message"] }` | Business rule violation |
| 429 | `{ "error": { "code": "rate_limited", "message": "..." } }` | Rack::Attack (HARDEN-002) |
| 500 | `{ "error": { "code": "internal_error", "message": "An unexpected error occurred" } }` | Unhandled exception |

## Acceptance Criteria
1. `RecordNotFound` returns generic "Resource not found" — no table/column names
2. `RecordInvalid` returns structured `{ "errors": { "field": ["msg"] } }` format
3. Unhandled exceptions return generic "An unexpected error occurred"
4. All errors are logged server-side with full exception details
5. A request spec verifies no internal details leak in 404 and 500 responses
6. `bundle exec rspec` passes

## Risks
- **Frontend impact**: The React frontend may currently parse `errors` as an array. The 422 validation format changes from `["Legal name can't be blank"]` to `{ "legal_name": ["can't be blank"] }`. Coordinate with frontend.
- **Debugging**: Developers must use server logs instead of API responses for debugging.

## Dependencies
- HARDEN-006 (Standardize Error Handling) should be done first

## Out of Scope
- Sentry integration
- Internationalized error messages
