# HARDEN-015: Protect AFIP-Authorized Invoices from Deletion

## Priority: P2 — Important
## Size: Small (2-3 hours)
## Theme: Data Integrity & Compliance

---

## Problem Statement
`client_invoices_controller.rb:39-41` and `credit_notes_controller.rb:37-39` allow hard-deleting any record:
```ruby
def destroy
  @client_invoice.destroy!
  head :no_content
end
```
AFIP-authorized invoices (with a CAE) are legally registered fiscal documents. Deleting them from our DB creates a discrepancy with AFIP's records and violates Argentina's 10-year retention requirement.

Additionally, `CreditNote` belongs to `ClientInvoice` via `client_invoice_id` — deleting the parent orphans credit notes (currently `dependent: :nullify` on `client_invoice.rb:6`).

## Files to Create/Modify

| File | Action |
|------|--------|
| `Gemfile` | Add `gem 'discard', '~> 1.3'` |
| New migration | Add `discarded_at` to `invoices` table |
| `app/models/invoice.rb` | Include `Discard::Model`, add deletion guard |
| `app/models/client_invoice.rb` | Inherit discard behavior |
| `app/models/credit_note.rb` | Inherit discard behavior |
| `app/controllers/api/v1/client_invoices_controller.rb` | Rewrite `destroy` action |
| `app/controllers/api/v1/credit_notes_controller.rb` | Rewrite `destroy` action |
| `spec/requests/invoice_protection_spec.rb` | Test deletion rules |

## Implementation Steps

### Step 1: Install discard gem
```ruby
# Gemfile
gem 'discard', '~> 1.3'
```
```bash
bundle install
```

### Step 2: Create migration
```bash
bin/rails generate migration AddDiscardedAtToInvoices discarded_at:datetime
```
```ruby
class AddDiscardedAtToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :discarded_at, :datetime
    add_index :invoices, :discarded_at
  end
end
```

### Step 3: Update `app/models/invoice.rb`
```ruby
class Invoice < ApplicationRecord
  include Discard::Model

  # ... existing associations and validations ...

  default_scope -> { kept }  # Exclude soft-deleted from all queries

  def afip_authorized?
    cae.present?
  end
end
```

**Note on `default_scope`**: The `discard` gem's `kept` scope filters out records where `discarded_at` is not null. Using `default_scope` ensures soft-deleted invoices are automatically excluded from index queries, filter services, and batch processes. Use `unscoped` or `with_discarded` when you need to access soft-deleted records.

### Step 4: Rewrite `destroy` in `client_invoices_controller.rb`
```ruby
def destroy
  if @client_invoice.afip_authorized?
    return render json: {
      error: {
        code: "cannot_delete",
        message: "Cannot delete an AFIP-authorized invoice. Issue a credit note instead."
      }
    }, status: :unprocessable_entity
  end

  @client_invoice.discard!
  head :no_content
end
```

### Step 5: Rewrite `destroy` in `credit_notes_controller.rb`
```ruby
def destroy
  if @credit_note.afip_authorized?
    return render json: {
      error: {
        code: "cannot_delete",
        message: "Cannot delete an AFIP-authorized credit note."
      }
    }, status: :unprocessable_entity
  end

  @credit_note.discard!
  head :no_content
end
```

### Step 6: Update scoping methods
The `default_scope -> { kept }` on `Invoice` automatically handles:
- `ClientInvoice.all_my_invoices(user_id)` — excludes discarded
- `ClientInvoice.where(user_id:).find(id)` — excludes discarded
- Filter services — no changes needed

If you prefer not to use `default_scope` (valid concern), instead update each scope:
```ruby
scope :all_my_invoices, ->(user_id) { kept.where(user_id: user_id) }
```

### Step 7: Write tests
```ruby
RSpec.describe "Invoice Deletion Protection", type: :request do
  let(:user) { create(:user) }

  context "authorized invoice (has CAE)" do
    let(:invoice) { create(:client_invoice, user: user, cae: "65012345678901") }

    it "returns 422 and does not delete" do
      delete "/api/v1/client_invoices/#{invoice.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(ClientInvoice.unscoped.find(invoice.id)).to be_present
    end
  end

  context "draft invoice (no CAE)" do
    let(:invoice) { create(:client_invoice, user: user, cae: nil) }

    it "soft-deletes and returns 204" do
      delete "/api/v1/client_invoices/#{invoice.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:no_content)
      expect(ClientInvoice.find_by(id: invoice.id)).to be_nil  # hidden by default_scope
      expect(ClientInvoice.unscoped.find(invoice.id).discarded_at).to be_present
    end
  end

  context "soft-deleted invoice" do
    let(:invoice) { create(:client_invoice, user: user, cae: nil, discarded_at: Time.current) }

    it "does not appear in index" do
      get "/api/v1/client_invoices", headers: auth_headers(user)
      ids = JSON.parse(response.body).map { |r| r["id"] }
      expect(ids).not_to include(invoice.id)
    end
  end
end
```

## Acceptance Criteria
1. `DELETE` on invoice with CAE returns HTTP 422 with explanatory message
2. `DELETE` on draft invoice soft-deletes (sets `discarded_at`)
3. Soft-deleted invoices excluded from index/filter queries
4. Credit notes with CAE also protected from deletion
5. `discarded_at` column added to invoices table
6. Tests verify: authorized can't delete, draft can soft-delete, soft-deleted excluded from index
7. `bundle exec rspec` passes

## Risks
- **`default_scope`**: Can cause subtle bugs if forgotten. Alternative: explicit `kept` scope in controllers/services. Choose one approach and be consistent.
- **Associated records**: Lines belong to invoices. When soft-deleting a draft, lines remain (they're still in the DB). This is fine — the invoice is just hidden.
- **Existing data**: All current records have `discarded_at: nil` — no migration needed.

## Dependencies
- Benefits from HARDEN-011 (`afip_status` field) — can check `authorized?` via status instead of CAE presence

## Out of Scope
- Archival policy
- Restoring soft-deleted invoices via API
- AFIP anulacion (not supported by AFIP — credit notes are the mechanism)
