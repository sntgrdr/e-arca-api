# HARDEN-019: Fix NameError Bug in Development GetLastInvoiceService

## Priority: P1 — High
## Size: XSmall (< 30 min)
## Theme: Bug Fix

---

## Problem Statement

`Invoices::Development::GetLastInvoiceService` has a NameError that makes it crash on every call. The `initialize` method sets `@sell_point_number` and `@afip_code`, but `attr_reader` declares `:sell_point` and `:invoice_type` — wrong names on both counts.

When `build_xml` calls `ERB.new(template).result(binding)`, the template references `sell_point_number` and `afip_code` as local variables/methods. These don't exist in the binding because the readers are named wrong, causing a `NameError`.

The production service (`Invoices::Production::GetLastInvoiceService`) avoids this with explicit method definitions — the dev service must match.

### Exact bug location

**File:** `app/services/invoices/development/get_last_invoice_service.rb`

| Line | Current (broken) | Should be |
|------|-----------------|-----------|
| 4 | `attr_reader :sell_point, :invoice_type, :legal_number` | `attr_reader :sell_point_number, :afip_code, :legal_number` |

### Evidence
- `spec/services/invoices/development/get_last_invoice_service_spec.rb` documents this defect — 4 of 5 examples stub `build_xml` to bypass it, and the 5th explicitly asserts the `NameError` is raised.

## File to Modify

| File | Change |
|------|--------|
| `app/services/invoices/development/get_last_invoice_service.rb` | Line 4: fix `attr_reader` names |

## Implementation

```ruby
# Before (broken)
attr_reader :sell_point, :invoice_type, :legal_number

# After (correct)
attr_reader :sell_point_number, :afip_code, :legal_number
```

## Acceptance Criteria
1. `Invoices::Development::GetLastInvoiceService.new(sell_point_number: 1, afip_code: 11, legal_number: '20-123-9').call` no longer raises `NameError`
2. All 5 examples in `spec/services/invoices/development/get_last_invoice_service_spec.rb` pass, including the previously-stubbed happy-path tests
3. `bundle exec rspec spec/services/invoices/development/get_last_invoice_service_spec.rb` passes

## Out of Scope
- Any changes to the production service (it's already correct)
- Changes to the ERB template

## RICE Score
- Reach: 100% of dev AFIP testing
- Impact: 2 (high — dev AFIP integration is completely broken without this)
- Confidence: 100%
- Effort: 0.1 person-weeks
- **Score: (100 × 2 × 1.0) / 0.1 = 2000**
