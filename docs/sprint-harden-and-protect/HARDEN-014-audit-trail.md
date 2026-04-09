# HARDEN-014: Add Invoice Audit Trail

## Priority: P2 — Important
## Size: Medium (3-4 hours)
## Theme: Compliance & Traceability

---

## Problem Statement
No change tracking on any model. `updated_at` only shows the last modification. For legally binding invoices submitted to AFIP, there's no way to reconstruct who changed what and when. Argentina requires 10-year tax record retention.

## Files to Create/Modify

| File | Action |
|------|--------|
| `Gemfile` | Add `gem 'paper_trail', '~> 16.0'` |
| New migration | Create `versions` table |
| `app/models/client_invoice.rb` | Add `has_paper_trail` |
| `app/models/credit_note.rb` | Add `has_paper_trail` |
| `app/models/client.rb` | Add `has_paper_trail` |
| `app/models/item.rb` | Add `has_paper_trail` (optional, lower priority) |
| `app/models/sell_point.rb` | Add `has_paper_trail` (optional, lower priority) |
| `app/controllers/api/v1/base_controller.rb` | Set `whodunnit` for PaperTrail |
| `app/controllers/api/v1/client_invoices_controller.rb` | Add `history` action |
| `config/routes.rb` | Add history route |
| `spec/models/client_invoice_audit_spec.rb` | Test audit entries |

## Implementation Steps

### Step 1: Install PaperTrail
```ruby
# Gemfile
gem 'paper_trail', '~> 16.0'
```
```bash
bundle install
bin/rails generate paper_trail:install
bin/rails db:migrate
```
This creates the `versions` table with: `item_type`, `item_id`, `event`, `whodunnit`, `object`, `object_changes`, `created_at`.

### Step 2: Set `whodunnit` in BaseController
Add to `app/controllers/api/v1/base_controller.rb`:
```ruby
before_action :set_paper_trail_whodunnit

private

def user_for_paper_trail
  current_user&.id&.to_s
end
```

### Step 3: Enable on models
```ruby
# app/models/client_invoice.rb
class ClientInvoice < Invoice
  has_paper_trail
  # ... existing code
end

# app/models/credit_note.rb
class CreditNote < Invoice
  has_paper_trail
  # ... existing code
end

# app/models/client.rb
class Client < ApplicationRecord
  has_paper_trail
  # ... existing code
end
```

### Step 4: Add custom AFIP events
In `SendToArcaService`, after persisting success/error, create an explicit audit event:

```ruby
# In persist_success! — add after invoice.update!
invoice.paper_trail.save_with_version(
  event: "afip_authorized",
  whodunnit: invoice.user_id.to_s
)
```

Alternatively, PaperTrail will automatically track the `update!` that sets the CAE — the version will show the `cae` field changing from `nil` to the value. This may be sufficient without custom events.

### Step 5: Add history API endpoint
```ruby
# config/routes.rb — inside client_invoices resources:
resources :client_invoices do
  member do
    get :history
    # ... existing routes
  end
end
```

```ruby
# app/controllers/api/v1/client_invoices_controller.rb
def history
  versions = @client_invoice.versions.order(created_at: :desc).map do |v|
    {
      id: v.id,
      event: v.event,
      who: v.whodunnit,
      when: v.created_at,
      changes: v.object_changes ? YAML.safe_load(v.object_changes) : {}
    }
  end
  render json: { history: versions }
end
```

Add `history` to the `before_action :set_invoice` list.

### Step 6: Backfill existing records
Create a migration or rake task:
```ruby
# In a migration or db/seeds:
ClientInvoice.find_each do |invoice|
  next if invoice.versions.any?
  PaperTrail::Version.create!(
    item: invoice,
    event: "create",
    whodunnit: invoice.user_id.to_s,
    created_at: invoice.created_at,
    object_changes: { "id" => [nil, invoice.id] }.to_yaml
  )
end
```

### Step 7: Write tests
```ruby
RSpec.describe "Invoice Audit Trail" do
  it "creates a version on invoice create" do
    invoice = create(:client_invoice)
    expect(invoice.versions.count).to eq(1)
    expect(invoice.versions.last.event).to eq("create")
  end

  it "creates a version on invoice update" do
    invoice = create(:client_invoice)
    invoice.update!(details: "Updated details")
    expect(invoice.versions.count).to eq(2)
  end

  it "records whodunnit" do
    # Set PaperTrail.request.whodunnit in test
    PaperTrail.request.whodunnit = user.id.to_s
    invoice = create(:client_invoice, user: user)
    expect(invoice.versions.last.whodunnit).to eq(user.id.to_s)
  end

  it "history endpoint returns versions" do
    invoice = create(:client_invoice, user: user)
    get "/api/v1/client_invoices/#{invoice.id}/history", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["history"]).to be_an(Array)
  end
end
```

## Acceptance Criteria
1. `paper_trail` gem installed and `versions` table created
2. `ClientInvoice` and `CreditNote` have `has_paper_trail`
3. `Client` has `has_paper_trail`
4. Every version records `whodunnit` (user ID)
5. AFIP authorization events are tracked (CAE field change captured automatically)
6. `GET /api/v1/client_invoices/:id/history` returns change history (scoped to resource owner)
7. Audit records are read-only via API (no update/delete endpoints for versions)
8. Tests verify create, update, and history endpoint
9. `bundle exec rspec` passes

## Risks
- **Storage**: Negligible for invoicing volume. Consider archiving after 10 years.
- **Performance**: One extra INSERT per tracked change — negligible.
- **Backfill**: Existing invoices won't have history. The backfill migration creates synthetic "create" events.

## Dependencies
- History endpoint should follow error patterns from HARDEN-007

## Out of Scope
- Admin dashboard for audit trails
- Automated compliance reporting
- Digital signatures on audit records
