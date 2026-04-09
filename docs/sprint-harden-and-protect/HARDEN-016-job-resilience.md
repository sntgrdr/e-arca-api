# HARDEN-016: Add Background Job Resilience

## Priority: P2 — Important
## Size: Small (2-3 hours)
## Theme: Reliability & Fault Tolerance

---

## Problem Statement
Two critical jobs have no retry logic, no granular error handling, and all-or-nothing failure modes:

### `app/jobs/bulk_invoice_creation_job.rb`
- Lines 22-24: `rescue => e` catches everything, marks entire batch as failed
- Lines 16-19: `find_each` loop creates invoices — if one fails after 80/100, all progress is lost (batch marked "failed")
- No idempotency: retrying creates duplicate invoices for already-processed clients
- No retry_on or discard_on

### `app/jobs/batch_pdf_generation_job.rb`
- Lines 16-19: `rescue => e` logs and re-raises — no retry, batch stays in limbo (never gets `pdf_generated: true`)
- No retry_on or discard_on

### Current `BatchInvoiceProcess` model (`app/models/batch_invoice_process.rb`):
- Has `status` enum: `pending`, `processing`, `completed`, `failed`
- Has `error_message` field
- Missing: `error_details` for per-client failure tracking, `failed_invoices` counter

## Files to Modify

| File | Action |
|------|--------|
| `app/jobs/bulk_invoice_creation_job.rb` | Add retry_on, idempotency, granular error handling |
| `app/jobs/batch_pdf_generation_job.rb` | Add retry_on, error recovery |
| New migration | Add `failed_invoices` and `error_details` to `batch_invoice_processes` |
| `spec/jobs/bulk_invoice_creation_job_spec.rb` | Test retry, idempotency, partial failure |
| `spec/jobs/batch_pdf_generation_job_spec.rb` | Test retry, error handling |

## Implementation Steps

### Step 1: Migration for tracking partial failures
```bash
bin/rails generate migration AddErrorTrackingToBatchInvoiceProcesses
```
```ruby
class AddErrorTrackingToBatchInvoiceProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :batch_invoice_processes, :failed_invoices, :integer, default: 0, null: false
    add_column :batch_invoice_processes, :error_details, :jsonb, default: []
  end
end
```

### Step 2: Rewrite `bulk_invoice_creation_job.rb`
```ruby
class BulkInvoiceCreationJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::ConnectionTimeoutError,
           ActiveRecord::Deadlocked,
           wait: :polynomially_longer,
           attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(batch_invoice_process_id)
    batch = BatchInvoiceProcess.find(batch_invoice_process_id)
    batch.update!(status: :processing)

    clients = if batch.client_group_id.present?
                batch.client_group.clients.where(active: true)
              else
                Client.all_my_clients(batch.user_id)
              end

    batch.update!(total_invoices: clients.count)

    clients.find_each do |client|
      # Idempotency: skip clients that already have an invoice in this batch
      next if ClientInvoice.exists?(batch_invoice_process_id: batch.id, client_id: client.id)

      begin
        create_invoice_for_client(batch, client)
        batch.increment!(:processed_invoices)
      rescue StandardError => e
        Rails.logger.error(
          "[BulkInvoiceCreationJob] batch_id=#{batch.id} client_id=#{client.id} " \
          "#{e.class}: #{e.message}"
        )
        batch.increment!(:failed_invoices)
        batch.update!(
          error_details: batch.error_details + [{
            client_id: client.id,
            client_name: client.legal_name,
            error: "#{e.class}: #{e.message}"
          }]
        )
      end
    end

    if batch.failed_invoices > 0
      batch.update!(
        status: :completed,
        error_message: "#{batch.processed_invoices} created, #{batch.failed_invoices} failed"
      )
    else
      batch.update!(status: :completed)
    end
  rescue StandardError => e
    Rails.logger.error("[BulkInvoiceCreationJob] batch_id=#{batch_invoice_process_id} FATAL: #{e.class}: #{e.message}")
    batch = BatchInvoiceProcess.find_by(id: batch_invoice_process_id)
    batch&.update!(status: :failed, error_message: e.message)
    raise # Let retry_on handle transient errors
  end

  private

  def create_invoice_for_client(batch, client)
    # ... existing implementation unchanged ...
  end
end
```

### Step 3: Rewrite `batch_pdf_generation_job.rb`
```ruby
class BatchPdfGenerationJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::ConnectionTimeoutError,
           Faraday::ConnectionFailed,
           wait: :polynomially_longer,
           attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(batch_invoice_process_id)
    batch = BatchInvoiceProcess.find(batch_invoice_process_id)

    zip_data = Invoices::BatchPdfZipGeneratorService.new(batch_process: batch).call

    batch.pdf_zip.attach(
      io: StringIO.new(zip_data),
      filename: "facturas_lote_#{batch.id}.zip",
      content_type: "application/zip"
    )

    batch.update!(pdf_generated: true)
  rescue StandardError => e
    Rails.logger.error(
      "[BatchPdfGenerationJob] batch_id=#{batch_invoice_process_id} #{e.class}: #{e.message}"
    )
    raise # Let retry_on handle transient errors; permanent failures exhaust retries
  end
end
```

### Step 4: Write tests
```ruby
# spec/jobs/bulk_invoice_creation_job_spec.rb
RSpec.describe BulkInvoiceCreationJob, type: :job do
  let(:batch) { create(:batch_invoice_process) }
  let!(:clients) { create_list(:client, 3, user: batch.user, client_group: batch.client_group) }

  it "creates invoices for all clients" do
    perform_enqueued_jobs { described_class.perform_later(batch.id) }
    expect(batch.reload.status).to eq("completed")
    expect(batch.processed_invoices).to eq(3)
  end

  it "skips clients that already have an invoice in this batch (idempotent)" do
    # Create one invoice manually for the first client
    create(:client_invoice, user: batch.user, client: clients.first,
           batch_invoice_process: batch)

    perform_enqueued_jobs { described_class.perform_later(batch.id) }
    # Should create 2 new invoices, not 3
    expect(ClientInvoice.where(batch_invoice_process_id: batch.id).count).to eq(3)
  end

  it "continues processing after individual invoice failure" do
    # Make the second client fail (e.g., missing required field)
    allow_any_instance_of(ClientInvoice).to receive(:save!).and_call_original
    # Stub specific failure...

    perform_enqueued_jobs { described_class.perform_later(batch.id) }
    batch.reload
    expect(batch.status).to eq("completed")
    expect(batch.failed_invoices).to be > 0
    expect(batch.error_details).to be_present
  end
end
```

## Acceptance Criteria
1. Both jobs use `retry_on` with polynomial backoff for transient errors (5 attempts)
2. `BulkInvoiceCreationJob` checks `ClientInvoice.exists?(batch_invoice_process_id:, client_id:)` before creating (idempotent)
3. `BulkInvoiceCreationJob` continues after individual failures — doesn't abort entire batch
4. `BatchInvoiceProcess` tracks `failed_invoices` count and `error_details` JSON
5. After max retries, job transitions batch to `failed` with error details
6. Both jobs log errors with batch context at appropriate levels
7. Tests verify: retry config, idempotent creation, partial failure handling
8. `bundle exec rspec` passes

## Risks
- **Idempotency key**: `(batch_id, client_id)` combination must be unique per batch. The `exists?` check handles this.
- **Solid Queue**: Supports `retry_on` and `discard_on` — it's the Rails 8 default.
- **Partial failures**: User needs visibility into which clients failed. The `error_details` JSONB column provides this.

## Dependencies
- Benefits from HARDEN-011 (AFIP idempotency) for consistent status patterns

## Out of Scope
- Job monitoring dashboard
- Email notifications on failure
- Automatic AFIP submission retry within batch jobs
