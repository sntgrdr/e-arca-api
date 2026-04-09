# HARDEN-006: Standardize Error Handling

## Priority: P1 — High
## Size: Small (1-2 hours)
## Theme: Code Quality & Reliability

---

## Problem Statement
The codebase has 3 bare `rescue => e` clauses that catch all `StandardError` without specifying the exception type. Some silently swallow errors. In a financial app submitting to AFIP, a silently swallowed error could mean an invoice is marked as sent when it wasn't.

### Exact locations of bare `rescue => e`:

| File | Line | Context |
|------|------|---------|
| `app/controllers/api/v1/profiles_controller.rb` | 28 | `rescue => e` in `last_invoice` action — catches everything, returns `e.message` to client |
| `app/jobs/bulk_invoice_creation_job.rb` | 22 | `rescue => e` in `perform` — catches everything, sets batch to "failed" |
| `app/jobs/batch_pdf_generation_job.rb` | 16 | `rescue => e` in `perform` — logs and re-raises, but doesn't specify exception type |

### Additional issue in development auth service:
| File | Line | Context |
|------|------|---------|
| `app/services/invoices/development/auth_with_arca_service.rb` | 100 | `rescue` (bare, no variable) in `cached_ta_valid?` — silently swallows any error |

## Files to Modify

| File | Action |
|------|--------|
| `app/controllers/api/v1/profiles_controller.rb` | Line 28: `rescue => e` → `rescue StandardError => e` + add logging |
| `app/jobs/bulk_invoice_creation_job.rb` | Line 22: `rescue => e` → `rescue StandardError => e` + add structured logging |
| `app/jobs/batch_pdf_generation_job.rb` | Line 16: `rescue => e` → `rescue StandardError => e` |
| `app/services/invoices/development/auth_with_arca_service.rb` | Line 100: `rescue` → `rescue StandardError => e` + log the error |

## Implementation Steps

### Step 1: Fix `profiles_controller.rb:28`
```ruby
# Before (line 28)
rescue => e
  render json: { error: e.message }, status: :unprocessable_entity

# After
rescue StandardError => e
  Rails.logger.error("[ProfilesController#last_invoice] #{e.class}: #{e.message}")
  render json: { error: e.message }, status: :unprocessable_entity
```

### Step 2: Fix `bulk_invoice_creation_job.rb:22`
```ruby
# Before (line 22)
rescue => e
  batch = BatchInvoiceProcess.find(batch_invoice_process_id)
  batch.update!(status: :failed, error_message: e.message)

# After
rescue StandardError => e
  Rails.logger.error("[BulkInvoiceCreationJob] batch_id=#{batch_invoice_process_id} #{e.class}: #{e.message}")
  batch = BatchInvoiceProcess.find(batch_invoice_process_id)
  batch.update!(status: :failed, error_message: e.message)
```

### Step 3: Fix `batch_pdf_generation_job.rb:16`
```ruby
# Before (line 16)
rescue => e
  Rails.logger.error("BatchPdfGenerationJob failed: #{e.message}")
  raise

# After
rescue StandardError => e
  Rails.logger.error("[BatchPdfGenerationJob] batch_id=#{batch_invoice_process_id} #{e.class}: #{e.message}")
  raise
```

### Step 4: Fix `development/auth_with_arca_service.rb:100`
```ruby
# Before (line 100)
rescue
  false

# After
rescue StandardError => e
  Rails.logger.warn("[AuthWithArcaService] Failed to read cached TA: #{e.class}: #{e.message}")
  false
```

### Step 5: Verify no remaining bare rescues
```bash
grep -rn 'rescue\s*=>' app/
grep -rn 'rescue$' app/ --include='*.rb'
```
Both should return zero results (excluding `rescue StandardError` and `rescue SpecificError`).

## Acceptance Criteria
1. Zero bare `rescue` or `rescue =>` in `app/` — only `rescue SpecificError =>` patterns
2. Every rescue block includes a `Rails.logger.error` (or `.warn` for non-critical) call with `e.class` and `e.message`
3. ARCA service failures include relevant context (service name, IDs)
4. `grep -rn 'rescue\s*=>' app/` returns zero results
5. `bundle exec rspec` passes

## Risks
- **Low risk**: Makes error handling explicit, no behavior change
- **Discovery**: May uncover errors that were previously swallowed silently — log as bugs, triage separately

## Dependencies
- Should be done before HARDEN-007 (Sanitize Error Responses)

## Out of Scope
- Custom exception classes
- Error monitoring integration (Sentry)
