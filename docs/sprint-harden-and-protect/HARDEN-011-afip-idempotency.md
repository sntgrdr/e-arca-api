# HARDEN-011: Add AFIP Submission Idempotency

## Priority: P1 — High
## Size: Medium (3-4 hours)
## Theme: Data Integrity & Financial Safety

---

## Problem Statement
The `send_to_arca` action can be called multiple times on any invoice. There is a partial guard — both `SendToArcaService` classes check `if @invoice.cae.present?` and return early — but:

1. **No status tracking**: There's no intermediate `submitting` state, so concurrent requests can both pass the CAE check and submit to AFIP simultaneously
2. **No lock**: No database-level protection against concurrent submissions
3. **Inconsistent return**: `client_invoices_controller.rb:46` checks `cae.present?` and returns 422 with an error, but `production/send_to_arca_service.rb:13` returns the invoice object directly — different behavior at different layers

### Current code flow:
```
Controller (client_invoices_controller.rb:45-46):
  if @client_invoice.cae.present? → 422 error

Service (production/send_to_arca_service.rb:13):
  return @invoice if @invoice.cae.present? → returns invoice (not a result hash)
```

## Files to Create/Modify

| File | Action |
|------|--------|
| New migration | Add `afip_status` column to `invoices` table |
| `app/models/invoice.rb` | Add `afip_status` enum and validation |
| `app/controllers/api/v1/client_invoices_controller.rb` | Rewrite `send_to_arca` with status checks |
| `app/controllers/api/v1/credit_notes_controller.rb` | Same rewrite for `send_to_arca` |
| `app/services/invoices/production/send_to_arca_service.rb` | Add status transitions |
| `app/services/invoices/development/send_to_arca_service.rb` | Same status transitions |
| `spec/requests/client_invoices_spec.rb` | Add idempotency tests |

## Implementation Steps

### Step 1: Create migration
```bash
bin/rails generate migration AddAfipStatusToInvoices afip_status:string
```

```ruby
class AddAfipStatusToInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :afip_status, :string, default: "draft", null: false
    add_index :invoices, :afip_status

    # Backfill existing records
    execute <<-SQL
      UPDATE invoices SET afip_status = 'authorized' WHERE cae IS NOT NULL;
      UPDATE invoices SET afip_status = 'rejected' WHERE afip_result = 'R' AND cae IS NULL;
    SQL
  end

  def down
    remove_column :invoices, :afip_status
  end
end
```

### Step 2: Update `app/models/invoice.rb`
```ruby
class Invoice < ApplicationRecord
  # ... existing code ...

  enum :afip_status, {
    draft: "draft",
    submitting: "submitting",
    authorized: "authorized",
    rejected: "rejected"
  }

  validates :afip_status, presence: true

  def submittable?
    draft? || rejected?
  end
end
```

### Step 3: Rewrite controller `send_to_arca` action
In `client_invoices_controller.rb`, replace the current `send_to_arca`:
```ruby
def send_to_arca
  # Idempotent: already authorized → return existing data
  if @client_invoice.authorized?
    return render json: @client_invoice, serializer: ClientInvoiceSerializer
  end

  # Concurrent protection: already submitting
  unless @client_invoice.submittable?
    return render json: {
      error: { code: "conflict", message: "Invoice is currently being processed" }
    }, status: :conflict
  end

  result = arca_service_module::SendToArcaService.new(invoice: @client_invoice).call

  if result[:success]
    render json: @client_invoice.reload, serializer: ClientInvoiceSerializer
  else
    render json: { errors: Array(result[:errors]) }, status: :unprocessable_entity
  end
end
```

Apply the same pattern to `credit_notes_controller.rb`.

### Step 4: Update `SendToArcaService` (both production and development)
Add status transitions around the AFIP call:

```ruby
def call
  return { success: true, invoice: @invoice } if @invoice.authorized?

  # Acquire lock + transition to submitting
  @invoice.with_lock do
    return { success: false, errors: "Invoice is being processed" } if @invoice.submitting?
    return { success: true, invoice: @invoice } if @invoice.authorized?
    @invoice.update!(afip_status: :submitting)
  end

  xml = soap_xml
  result = send_to_arca(xml)
  process_afip_response(result[:body])
rescue StandardError => e
  @invoice.update!(afip_status: :rejected) if @invoice.submitting?
  raise
end
```

In `persist_success!`, add: `afip_status: :authorized`
In `persist_error!`, add: `afip_status: :rejected`

### Step 5: Write tests
```ruby
# Key scenarios to test:
it "returns existing CAE data when invoice is already authorized" do
  # Create invoice with CAE → call send_to_arca → expect 200 with serialized invoice
end

it "returns 409 when invoice is currently submitting" do
  # Set invoice afip_status to :submitting → call send_to_arca → expect 409
end

it "transitions status from draft → submitting → authorized on success" do
  # Mock AFIP response → verify status transitions
end

it "transitions status from draft → submitting → rejected on failure" do
  # Mock AFIP rejection → verify status = rejected
end
```

## Acceptance Criteria
1. `invoices` table has `afip_status` column with values: `draft`, `submitting`, `authorized`, `rejected`
2. Existing invoices with CAE are backfilled to `authorized`, those with `afip_result='R'` to `rejected`, rest to `draft`
3. Calling `send_to_arca` on an `authorized` invoice returns 200 with existing data (no re-submission)
4. Calling `send_to_arca` on a `submitting` invoice returns 409 Conflict
5. `with_lock` prevents concurrent submissions of the same invoice
6. Status transitions: `draft` → `submitting` → `authorized`/`rejected`
7. Tests verify idempotency and conflict behavior
8. `bundle exec rspec` passes

## Risks
- **Migration**: Backfill query must handle existing data correctly. Test on a staging copy first.
- **Stuck invoices**: If server crashes during `submitting`, invoice stays stuck. Recovery: query AFIP via `FECompUltimoAutorizado` (already in codebase as `LastInvoiceQueryService`).
- **Lock duration**: `with_lock` holds a row-level DB lock only for the status transition, not the full AFIP call — this is intentional to avoid long-held locks.

## Dependencies
- Benefits from HARDEN-006 (error handling) and HARDEN-010 (remove constantize)

## Out of Scope
- Automatic retry of failed submissions
- Recovery job for stuck `submitting` invoices (future ticket)
