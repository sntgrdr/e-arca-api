# HARDEN-017: Test Coverage for Filter Services and Background Jobs

## Priority: P2 — Important
## Size: Medium (3-4 hours)
## Theme: Quality & Reliability

---

## Problem Statement
Three filter services and two background jobs have zero test coverage. These are high-traffic code paths that change frequently.

### Current code to test:

**Filter services:**
| Service | File | Filters |
|---------|------|---------|
| `ClientsFilterService` | `app/services/filters/clients_filter_service.rb` | `legal_name`, `legal_number`, `name`, `tax_condition`, `client_group_id` |
| `ItemsFilterService` | `app/services/filters/items_filter_service.rb` | `code`, `name`, `iva_id`, `price_from`, `price_to` |
| `ClientInvoicesFilterService` | `app/services/filters/client_invoices_filter_service.rb` | `number`, `date_from`, `date_to`, `period_from`, `period_to`, `client_name`, `total_price_from`, `total_price_to` |

**Background jobs** (covered by HARDEN-016 for resilience, this ticket covers functional tests):
| Job | File |
|-----|------|
| `BulkInvoiceCreationJob` | `app/jobs/bulk_invoice_creation_job.rb` |
| `BatchPdfGenerationJob` | `app/jobs/batch_pdf_generation_job.rb` |

### Key implementation detail from `ClientsFilterService` (`app/services/filters/clients_filter_service.rb`):
- Uses `ILIKE` for partial matching (lines 29, 35, 42)
- Uses `ActiveRecord::Base.sanitize_sql_like` for SQL injection protection (line 69)
- Has rescue block that falls back to unfiltered scope on error (lines 16-18)
- Uses `stripped_param` and `array_param` helpers for nil/empty handling

## Files to Create

| File | Covers |
|------|--------|
| `spec/services/filters/clients_filter_service_spec.rb` | All client filters |
| `spec/services/filters/items_filter_service_spec.rb` | All item filters |
| `spec/services/filters/client_invoices_filter_service_spec.rb` | All invoice filters |
| `spec/jobs/bulk_invoice_creation_job_spec.rb` | Job functional tests |
| `spec/jobs/batch_pdf_generation_job_spec.rb` | Job functional tests |

## Implementation Steps

### Step 1: Test `ClientsFilterService`
```ruby
# spec/services/filters/clients_filter_service_spec.rb
RSpec.describe Filters::ClientsFilterService do
  let(:user) { create(:user) }
  let(:scope) { Client.where(user_id: user.id) }

  let!(:client_a) { create(:client, user: user, legal_name: "Empresa ABC", name: "Juan", tax_condition: "monotributista") }
  let!(:client_b) { create(:client, user: user, legal_name: "Comercio XYZ", name: "Maria", tax_condition: "responsable_inscripto") }

  subject { described_class.new(params, scope).call }

  describe "filter by legal_name" do
    let(:params) { { legal_name: "ABC" } }
    it "returns partial case-insensitive matches" do
      expect(subject).to include(client_a)
      expect(subject).not_to include(client_b)
    end
  end

  describe "filter by legal_name (case insensitive)" do
    let(:params) { { legal_name: "abc" } }
    it { expect(subject).to include(client_a) }
  end

  describe "filter by tax_condition" do
    let(:params) { { tax_condition: ["monotributista"] } }
    it "returns exact matches" do
      expect(subject).to include(client_a)
      expect(subject).not_to include(client_b)
    end
  end

  describe "filter by client_group_id" do
    let(:group) { create(:client_group, user: user) }
    let!(:client_a) { create(:client, user: user, client_group: group) }
    let(:params) { { client_group_id: [group.id] } }
    it { expect(subject).to include(client_a) }
  end

  describe "combined filters" do
    let(:params) { { legal_name: "Empresa", tax_condition: ["monotributista"] } }
    it "applies all filters" do
      expect(subject).to include(client_a)
      expect(subject).not_to include(client_b)
    end
  end

  describe "empty/nil params" do
    let(:params) { { legal_name: "", name: nil } }
    it "returns unfiltered scope" do
      expect(subject).to include(client_a, client_b)
    end
  end

  describe "SQL injection protection" do
    let(:params) { { legal_name: "'; DROP TABLE clients; --" } }
    it "handles malicious input safely" do
      expect { subject.to_a }.not_to raise_error
    end
  end
end
```

### Step 2: Test `ItemsFilterService`
```ruby
# spec/services/filters/items_filter_service_spec.rb
RSpec.describe Filters::ItemsFilterService do
  # Test: code (partial), name (partial), iva_id (exact)
  # Test: price_from, price_to (range)
  # Test: boundary: price_from = 0, price_from > price_to
  # Test: empty params → unfiltered
  # Test: combined filters
end
```

### Step 3: Test `ClientInvoicesFilterService`
```ruby
# spec/services/filters/client_invoices_filter_service_spec.rb
RSpec.describe Filters::ClientInvoicesFilterService do
  # Test: number (partial match)
  # Test: date_from, date_to (date range)
  # Test: period_from, period_to (period range)
  # Test: client_name (cross-association partial match)
  # Test: total_price_from, total_price_to (amount range)
  # Test: combined filters
  # Test: empty params → unfiltered
end
```

### Step 4: Test `BulkInvoiceCreationJob`
```ruby
# spec/jobs/bulk_invoice_creation_job_spec.rb
RSpec.describe BulkInvoiceCreationJob, type: :job do
  let(:user) { create(:user) }
  let(:group) { create(:client_group, user: user) }
  let(:item) { create(:item, user: user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:batch) { create(:batch_invoice_process, user: user, client_group: group, item: item, sell_point: sell_point) }
  let!(:clients) { create_list(:client, 3, user: user, client_group: group, active: true) }

  it "creates invoices for all active clients in the group" do
    expect { perform_enqueued_jobs { described_class.perform_later(batch.id) } }
      .to change(ClientInvoice, :count).by(3)
  end

  it "sets correct attributes on created invoices" do
    perform_enqueued_jobs { described_class.perform_later(batch.id) }
    invoice = ClientInvoice.last
    expect(invoice.user_id).to eq(user.id)
    expect(invoice.sell_point_id).to eq(sell_point.id)
    expect(invoice.date).to eq(batch.date)
    expect(invoice.batch_invoice_process_id).to eq(batch.id)
  end

  it "increments processed_invoices counter" do
    perform_enqueued_jobs { described_class.perform_later(batch.id) }
    expect(batch.reload.processed_invoices).to eq(3)
  end

  it "sets batch status to completed" do
    perform_enqueued_jobs { described_class.perform_later(batch.id) }
    expect(batch.reload.status).to eq("completed")
  end

  it "sets batch status to failed on unrecoverable error" do
    allow(BatchInvoiceProcess).to receive(:find).and_raise(StandardError, "boom")
    # This depends on retry behavior — may need adjustment
    expect { perform_enqueued_jobs { described_class.perform_later(batch.id) } }
      .to raise_error(StandardError)
  end

  context "with no active clients" do
    let!(:clients) { [] }
    it "completes with 0 processed" do
      perform_enqueued_jobs { described_class.perform_later(batch.id) }
      expect(batch.reload.status).to eq("completed")
      expect(batch.processed_invoices).to eq(0)
    end
  end
end
```

### Step 5: Test `BatchPdfGenerationJob`
```ruby
# spec/jobs/batch_pdf_generation_job_spec.rb
RSpec.describe BatchPdfGenerationJob, type: :job do
  let(:batch) { create(:batch_invoice_process, :completed) }

  it "attaches a ZIP file to the batch" do
    # Mock PDF generation to avoid Prawn overhead in tests
    allow_any_instance_of(Invoices::BatchPdfZipGeneratorService)
      .to receive(:call).and_return("fake_zip_data")

    perform_enqueued_jobs { described_class.perform_later(batch.id) }
    batch.reload
    expect(batch.pdf_generated).to be true
    expect(batch.pdf_zip).to be_attached
  end
end
```

### Step 6: Configure test environment
Ensure `spec/rails_helper.rb` has:
```ruby
config.active_job.queue_adapter = :test
```
Use `perform_enqueued_jobs` block when testing job side effects.

## Acceptance Criteria
1. Each filter service has a spec with tests for every supported filter parameter
2. Filter specs test: individual params, combined params, empty/nil handling, SQL injection safety
3. Both jobs have specs for: happy path, counter increments, status transitions, error handling
4. Job specs use factories for realistic test data
5. All specs run without external dependencies (no HTTP calls, mocked PDF generation)
6. Code coverage for `app/services/filters/` and `app/jobs/` reaches at least 90%
7. `bundle exec rspec` passes

## Risks
- **Test data**: Jobs require complete factory graphs (user → client_group → clients, item → iva, sell_point). Ensure factories have proper associations.
- **PDF mocking**: Mock `Invoices::BatchPdfZipGeneratorService` in job tests. Full PDF generation is tested in HARDEN-012.
- **Solid Queue**: Use `queue_adapter = :test` in test env with `perform_enqueued_jobs`.

## Dependencies
- Independent, but logically follows HARDEN-012 and HARDEN-016

## Out of Scope
- Performance benchmarks
- Load testing
- Filter service refactoring
