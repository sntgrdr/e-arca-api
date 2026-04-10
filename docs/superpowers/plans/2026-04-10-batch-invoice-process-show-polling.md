# Batch Invoice Process Show — Polling-Ready Response Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich `BatchInvoiceProcessesController#show` to return associated `client_invoices` (capped at 200) with cap metadata and `updated_at`, and enrich `index` with `item` and `sell_point`.

**Architecture:** Two new serializers (`BatchClientInvoiceSerializer`, `BatchInvoiceProcessDetailSerializer`) handle the shape. The controller's `show` does a single ownership-scoped query; `index` adds `includes`. All conditional logic (`error_details`, cap metadata) lives in the serializers.

**Tech Stack:** Rails 8.1, ActiveModel::Serializers, RSpec request specs, FactoryBot.

---

## File Map

| Action | File |
|--------|------|
| Create | `app/serializers/batch_client_invoice_serializer.rb` |
| Create | `app/serializers/batch_invoice_process_detail_serializer.rb` |
| Modify | `app/serializers/batch_invoice_process_serializer.rb` |
| Modify | `app/controllers/api/v1/batch_invoice_processes_controller.rb` |
| Create | `spec/requests/batch_invoice_processes_spec.rb` |

---

## Task 1: Write failing request specs

**Files:**
- Create: `spec/requests/batch_invoice_processes_spec.rb`

- [ ] **Step 1: Create the spec file**

```ruby
# spec/requests/batch_invoice_processes_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::BatchInvoiceProcesses', type: :request do
  let(:user)       { create(:user) }
  let(:headers)    { auth_headers(user) }
  let(:iva)        { create(:iva, user: user) }
  let(:item)       { create(:item, user: user, iva: iva) }
  let(:sell_point) { create(:sell_point, user: user) }

  describe 'GET /api/v1/batch_invoice_processes' do
    before do
      create_list(:batch_invoice_process, 2, user: user, item: item, sell_point: sell_point)
    end

    it 'returns processes with item and sell_point' do
      get '/api/v1/batch_invoice_processes', headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
      expect(body.first).to include('item', 'sell_point')
      expect(body.first['item']).to include('id', 'name', 'code')
      expect(body.first['sell_point']).to include('id', 'number')
    end

    it 'does not include client_invoices' do
      get '/api/v1/batch_invoice_processes', headers: headers, as: :json
      body = JSON.parse(response.body)
      expect(body.first).not_to have_key('client_invoices')
    end
  end

  describe 'GET /api/v1/batch_invoice_processes/:id' do
    let(:batch) do
      create(:batch_invoice_process, user: user, item: item, sell_point: sell_point)
    end

    context 'with associated invoices' do
      let(:client) { create(:client, user: user, iva: iva) }

      before do
        create_list(:client_invoice, 3, user: user, client: client, sell_point: sell_point,
                    batch_invoice_process: batch)
      end

      it 'returns client_invoices with slim fields' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key('client_invoices')
        invoice = body['client_invoices'].first
        expect(invoice.keys).to match_array(%w[id number date client_name client_legal_number
                                               cae afip_authorized_at total_price])
      end

      it 'returns client_invoices_total and client_invoices_capped' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['client_invoices_total']).to eq(3)
        expect(body['client_invoices_capped']).to eq(false)
      end

      it 'returns updated_at' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body).to have_key('updated_at')
      end

      it 'sets Cache-Control: no-store' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        expect(response.headers['Cache-Control']).to include('no-store')
      end
    end

    context 'when batch has more than 200 invoices' do
      let(:client) { create(:client, user: user, iva: iva) }

      before do
        create_list(:client_invoice, 201, user: user, client: client, sell_point: sell_point,
                    batch_invoice_process: batch)
      end

      it 'returns at most 200 invoices' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['client_invoices'].length).to eq(200)
      end

      it 'returns client_invoices_capped: true and correct total' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['client_invoices_capped']).to eq(true)
        expect(body['client_invoices_total']).to eq(201)
      end
    end

    context 'when status is failed' do
      let(:batch_failed) do
        create(:batch_invoice_process, :failed, user: user, item: item, sell_point: sell_point,
               error_details: [{ client_id: 1, error: 'AFIP timeout' }])
      end

      it 'returns error_details' do
        get "/api/v1/batch_invoice_processes/#{batch_failed.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body).to have_key('error_details')
        expect(body['error_details']).not_to be_empty
      end
    end

    context 'when status is completed' do
      let(:batch_completed) do
        create(:batch_invoice_process, :completed, user: user, item: item, sell_point: sell_point)
      end

      it 'does not return error_details' do
        get "/api/v1/batch_invoice_processes/#{batch_completed.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body).not_to have_key('error_details')
      end
    end

    context 'tenant isolation' do
      it_behaves_like 'a user-scoped resource' do
        let(:resource_path) { '/api/v1/batch_invoice_processes' }
        let(:resource) do
          iva_a   = create(:iva, user: user_a)
          item_a  = create(:item, user: user_a, iva: iva_a)
          sp_a    = create(:sell_point, user: user_a)
          create(:batch_invoice_process, user: user_a, item: item_a, sell_point: sp_a)
        end
        let(:resource_list) do
          iva_a   = create(:iva, user: user_a)
          item_a  = create(:item, user: user_a, iva: iva_a)
          sp_a    = create(:sell_point, user: user_a)
          create_list(:batch_invoice_process, 2, user: user_a, item: item_a, sell_point: sp_a)
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run specs to confirm they fail**

```bash
bundle exec rspec spec/requests/batch_invoice_processes_spec.rb --format documentation
```

Expected: multiple failures — serializer methods and controller changes not yet implemented.

- [ ] **Step 3: Commit the failing specs**

```bash
git add spec/requests/batch_invoice_processes_spec.rb
git commit -m "test: add failing request specs for batch invoice process enrichment"
```

---

## Task 2: Update `BatchInvoiceProcessSerializer` for index

**Files:**
- Modify: `app/serializers/batch_invoice_process_serializer.rb`

- [ ] **Step 1: Replace the serializer**

```ruby
# app/serializers/batch_invoice_process_serializer.rb
class BatchInvoiceProcessSerializer < ActiveModel::Serializer
  attributes :id, :status, :date, :period, :total_invoices,
             :processed_invoices, :failed_invoices, :pdf_generated,
             :error_message, :client_group_id, :item_id, :sell_point_id, :created_at

  def item
    { id: object.item.id, name: object.item.name, code: object.item.code }
  end

  def sell_point
    { id: object.sell_point.id, number: object.sell_point.number }
  end
end
```

- [ ] **Step 2: Update `index` in the controller to add `includes`**

In `app/controllers/api/v1/batch_invoice_processes_controller.rb`, replace:

```ruby
def index
  processes = policy_scope(BatchInvoiceProcess).order(created_at: :desc)
  render json: processes, each_serializer: BatchInvoiceProcessSerializer
end
```

with:

```ruby
def index
  processes = policy_scope(BatchInvoiceProcess)
    .includes(:item, :sell_point)
    .order(created_at: :desc)
  render json: processes, each_serializer: BatchInvoiceProcessSerializer
end
```

- [ ] **Step 3: Run index specs only**

```bash
bundle exec rspec spec/requests/batch_invoice_processes_spec.rb -e "GET /api/v1/batch_invoice_processes" --format documentation
```

Expected: both index examples pass.

- [ ] **Step 4: Commit**

```bash
git add app/serializers/batch_invoice_process_serializer.rb \
        app/controllers/api/v1/batch_invoice_processes_controller.rb
git commit -m "feat: enrich batch invoice process index with item and sell_point"
```

---

## Task 3: Create `BatchClientInvoiceSerializer`

**Files:**
- Create: `app/serializers/batch_client_invoice_serializer.rb`

- [ ] **Step 1: Create the serializer**

```ruby
# app/serializers/batch_client_invoice_serializer.rb
class BatchClientInvoiceSerializer < ActiveModel::Serializer
  attributes :id, :number, :date, :cae, :afip_authorized_at, :total_price

  def client_name
    object.client.legal_name
  end

  def client_legal_number
    object.client.legal_number
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/serializers/batch_client_invoice_serializer.rb
git commit -m "feat: add BatchClientInvoiceSerializer for slim invoice shape in batch show"
```

---

## Task 4: Create `BatchInvoiceProcessDetailSerializer`

**Files:**
- Create: `app/serializers/batch_invoice_process_detail_serializer.rb`

- [ ] **Step 1: Create the serializer**

```ruby
# app/serializers/batch_invoice_process_detail_serializer.rb
class BatchInvoiceProcessDetailSerializer < ActiveModel::Serializer
  INVOICE_CAP = 200

  attributes :id, :status, :date, :period, :total_invoices,
             :processed_invoices, :failed_invoices, :pdf_generated,
             :error_message, :error_details, :client_group_id, :item_id,
             :sell_point_id, :created_at, :updated_at,
             :client_invoices, :client_invoices_capped, :client_invoices_total

  def client_invoices
    object.client_invoices
          .includes(:client)
          .order(created_at: :asc)
          .limit(INVOICE_CAP)
          .map { |inv| BatchClientInvoiceSerializer.new(inv).attributes }
  end

  def client_invoices_total
    @client_invoices_total ||= object.client_invoices.count
  end

  def client_invoices_capped
    client_invoices_total > INVOICE_CAP
  end

  def error_details
    object.error_details if object.failed?
  end

  # Remove error_details key entirely when not failed (not just null)
  def attributes(*args)
    data = super
    data.delete(:error_details) unless object.failed?
    data
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/serializers/batch_invoice_process_detail_serializer.rb
git commit -m "feat: add BatchInvoiceProcessDetailSerializer with capped invoices and cap metadata"
```

---

## Task 5: Update controller `show` and `before_action`

**Files:**
- Modify: `app/controllers/api/v1/batch_invoice_processes_controller.rb`

- [ ] **Step 1: Update `before_action` and `show`**

Replace the current `before_action` line and `show` action:

```ruby
# Change this line at the top of the controller:
before_action :set_batch_process, only: %i[show generate_pdfs download_pdfs]
```

to:

```ruby
before_action :set_batch_process, only: %i[generate_pdfs download_pdfs]
```

Replace:

```ruby
def show
  authorize @batch_process
  render json: @batch_process, serializer: BatchInvoiceProcessSerializer
end
```

with:

```ruby
def show
  batch = BatchInvoiceProcess
    .where(user_id: current_user.id)
    .find(params[:id])
  authorize batch
  response.set_header('Cache-Control', 'no-store')
  render json: batch, serializer: BatchInvoiceProcessDetailSerializer
end
```

- [ ] **Step 2: Run the full spec file**

```bash
bundle exec rspec spec/requests/batch_invoice_processes_spec.rb --format documentation
```

Expected: all examples pass.

- [ ] **Step 3: Run the full suite to check for regressions**

```bash
bundle exec rspec --format progress
```

Expected: no new failures.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/api/v1/batch_invoice_processes_controller.rb
git commit -m "feat: update batch invoice process show with detail serializer and no-store cache header"
```
