# HARDEN-013: Test Coverage for Multi-Tenancy Enforcement

## Priority: P2 — Important
## Size: Medium (3-4 hours)
## Theme: Security Verification

---

## Problem Statement
All controllers scope data via `where(user_id: current_user.id)` but zero tests verify this isolation. All existing request specs use a single user — there is no "User B tries to access User A's data" scenario.

### Controllers and their scoping methods:

| Controller | Scoping | File:Line |
|------------|---------|-----------|
| ClientsController | `Client.where(user_id: current_user.id).find(params[:id])` | `client_invoices_controller.rb:42` |
| ClientGroupsController | `ClientGroup.where(user_id: current_user.id).find(params[:id])` | `client_groups_controller.rb:40` |
| ItemsController | `Item.where(user_id: current_user.id).find(params[:id])` | `items_controller.rb:58` |
| IvasController | `Iva.where(user_id: current_user.id).find(params[:id])` | `ivas_controller.rb:40` |
| SellPointsController | `SellPoint.where(user_id: current_user.id).find(params[:id])` | `sell_points_controller.rb:42` |
| ClientInvoicesController | `ClientInvoice.where(user_id: current_user.id).find(params[:id])` | `client_invoices_controller.rb:72` |
| CreditNotesController | `CreditNote.where(user_id: current_user.id).find(params[:id])` | `credit_notes_controller.rb:58` |
| BatchInvoiceProcessesController | `BatchInvoiceProcess.where(user_id: current_user.id).find(params[:id])` | `batch_invoice_processes_controller.rb:59` |

### Index scoping (via class methods):
| Controller | Scope Method |
|------------|-------------|
| ClientsController | `Client.all_my_clients(current_user.id)` |
| ItemsController | `Item.all_my_items(current_user.id)` |
| IvasController | `Iva.all_my_ivas(current_user.id)` |
| SellPointsController | `SellPoint.all_my_sell_points(current_user.id)` |
| ClientInvoicesController | `ClientInvoice.all_my_invoices(current_user.id)` |
| BatchInvoiceProcessesController | `BatchInvoiceProcess.all_my_processes(current_user.id)` |

## Files to Create

| File | Action |
|------|--------|
| `spec/support/shared_examples/user_scoped_resource.rb` | Create shared examples for cross-user tests |
| `spec/requests/multi_tenancy/clients_spec.rb` | Cross-user tests for clients |
| `spec/requests/multi_tenancy/client_groups_spec.rb` | Cross-user tests for client groups |
| `spec/requests/multi_tenancy/items_spec.rb` | Cross-user tests for items |
| `spec/requests/multi_tenancy/ivas_spec.rb` | Cross-user tests for ivas |
| `spec/requests/multi_tenancy/sell_points_spec.rb` | Cross-user tests for sell points |
| `spec/requests/multi_tenancy/client_invoices_spec.rb` | Cross-user tests for invoices |
| `spec/requests/multi_tenancy/credit_notes_spec.rb` | Cross-user tests for credit notes |
| `spec/requests/multi_tenancy/batch_invoice_processes_spec.rb` | Cross-user tests for batch processes |

## Implementation Steps

### Step 1: Create shared examples
```ruby
# spec/support/shared_examples/user_scoped_resource.rb
RSpec.shared_examples "a user-scoped resource" do |resource_path, factory_name|
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let!(:resource_a) { create(factory_name, user: user_a) }

  describe "cross-user access" do
    it "returns 404 when user_b tries to GET user_a's resource" do
      get "#{resource_path}/#{resource_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when user_b tries to PATCH user_a's resource" do
      patch "#{resource_path}/#{resource_a.id}",
            params: { factory_name => { name: "hacked" } }.to_json,
            headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when user_b tries to DELETE user_a's resource" do
      delete "#{resource_path}/#{resource_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it "index returns only user_b's resources (not user_a's)" do
      create(factory_name, user: user_b) # user_b's own resource
      get resource_path, headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)

      ids = JSON.parse(response.body).map { |r| r["id"] }
      expect(ids).not_to include(resource_a.id)
    end
  end
end
```

### Step 2: Use shared examples in each spec
```ruby
# spec/requests/multi_tenancy/clients_spec.rb
RSpec.describe "Multi-tenancy: Clients", type: :request do
  it_behaves_like "a user-scoped resource", "/api/v1/clients", :client
end

# spec/requests/multi_tenancy/client_invoices_spec.rb
RSpec.describe "Multi-tenancy: Client Invoices", type: :request do
  it_behaves_like "a user-scoped resource", "/api/v1/client_invoices", :client_invoice

  describe "send_to_arca cross-user" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }
    let!(:invoice_a) { create(:client_invoice, user: user_a) }

    it "returns 404 when user_b tries to send user_a's invoice to ARCA" do
      patch "/api/v1/client_invoices/#{invoice_a.id}/send_to_arca",
            headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

### Step 3: Adapt shared examples per resource
Some resources have non-standard params (e.g., `client_invoice` requires nested `lines_attributes`). The shared examples handle `GET`, `PATCH`, `DELETE` generically. For `PATCH`, use a minimal valid param or skip if the resource doesn't support update.

### Step 4: Test index counts
For index endpoints, verify that:
```ruby
it "user_a sees 2 clients, user_b sees 0" do
  create_list(:client, 2, user: user_a)
  get "/api/v1/clients", headers: auth_headers(user_b)
  # Depending on pagination format:
  body = JSON.parse(response.body)
  expect(body["data"]&.length || body.length).to eq(0)
end
```

### Step 5: Ensure 404 not 403
All cross-user access should return 404 (hiding resource existence) not 403. The current `where(user_id:).find(id)` pattern already does this — `ActiveRecord::RecordNotFound` is raised, mapped to 404 in `BaseController`.

## Acceptance Criteria
1. Every resource has at least one cross-user test for show, update, and delete
2. Index endpoints verified: User B sees 0 of User A's resources
3. All cross-user access returns HTTP 404 (not 403, not 500)
4. Tests use two separate user factories with separate resources
5. Shared example `it_behaves_like "a user-scoped resource"` created for DRY tests
6. `send_to_arca` and `download_pdf` cross-user tests for invoices/credit notes
7. `bundle exec rspec` passes on CI

## Risks
- **Test discovery**: These tests may reveal actual multi-tenancy bugs. Treat any failure as P0.
- **Factory complexity**: Some resources require associated records (invoice needs client, sell_point, lines). Ensure factories are complete.

## Dependencies
- Pairs with HARDEN-004 (Pundit) — if Pundit is implemented first, cross-user tests should verify Pundit returns 403 (then update `BaseController` to convert to 404 to hide resource existence)

## Out of Scope
- Row-level security (PostgreSQL RLS)
- Penetration testing / IDOR fuzzing
