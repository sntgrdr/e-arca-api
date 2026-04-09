# HARDEN-010: Remove Dynamic Class Loading (`constantize`)

## Priority: P1 — High
## Size: Small (30 min)
## Theme: Code Safety

---

## Problem Statement
Two controllers use `constantize` to dynamically resolve ARCA service classes:

| File | Line | Code |
|------|------|------|
| `app/controllers/api/v1/client_invoices_controller.rb` | 49 | `"Invoices::#{Rails.env.camelize}::SendToArcaService".constantize.new(invoice: @client_invoice).call` |
| `app/controllers/api/v1/credit_notes_controller.rb` | 47 | `"Invoices::#{Rails.env.camelize}::SendToArcaService".constantize.new(invoice: @credit_note).call` |

`constantize` is a known RCE vector and makes code untraceable by IDE search, static analysis (Brakeman will flag this), and `grep`.

## Files to Modify

| File | Action |
|------|--------|
| `app/controllers/api/v1/base_controller.rb` | Add `arca_service_module` helper method |
| `app/controllers/api/v1/client_invoices_controller.rb` | Line 49: Replace `constantize` with helper |
| `app/controllers/api/v1/credit_notes_controller.rb` | Line 47: Replace `constantize` with helper |

## Implementation Steps

### Step 1: Add helper to `base_controller.rb`
Add to the `private` section of `BaseController`:
```ruby
def arca_service_module
  Rails.env.production? ? Invoices::Production : Invoices::Development
end
```

### Step 2: Update `client_invoices_controller.rb:49`
```ruby
# Before
result = "Invoices::#{Rails.env.camelize}::SendToArcaService".constantize.new(invoice: @client_invoice).call

# After
result = arca_service_module::SendToArcaService.new(invoice: @client_invoice).call
```

### Step 3: Update `credit_notes_controller.rb:47`
```ruby
# Before
result = "Invoices::#{Rails.env.camelize}::SendToArcaService".constantize.new(invoice: @credit_note).call

# After
result = arca_service_module::SendToArcaService.new(invoice: @credit_note).call
```

### Step 4: Verify no remaining `constantize`
```bash
grep -rn 'constantize' app/
# Should return zero results
```

### Step 5: Run tests
```bash
bundle exec rspec
```

## Acceptance Criteria
1. Zero occurrences of `constantize` in `app/`
2. Service selection uses explicit conditional via `arca_service_module`
3. Test environment maps to `Invoices::Development` (same as development)
4. `grep -rn 'constantize' app/` returns zero results
5. `bundle exec rspec` passes

## Risks
- **Very low risk**: Straightforward refactor, identical behavior
- **Test environment**: `Rails.env.production?` returns `false` in test, so test uses `Invoices::Development` — same as current behavior since `"Test".camelize` would have produced `Invoices::Test` which doesn't exist (current code is already broken for test env, masked by test doubles)

## Dependencies
- None

## Out of Scope
- Refactoring the development/production service class structure
- Merging dev/prod services into a single configurable service
