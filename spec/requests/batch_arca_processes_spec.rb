require "rails_helper"

RSpec.describe "Api::V1::BatchArcaProcesses", type: :request do
  let(:user)       { create(:user) }
  let(:headers)    { auth_headers(user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }
  let(:invoices) do
    create_list(:client_invoice, 3, user: user, sell_point: sell_point,
                client: client, invoice_type: "C", afip_status: :draft)
  end

  describe "POST /api/v1/batch_arca_processes" do
    let(:valid_params) do
      {
        batch_arca_process: {
          invoice_ids:     invoices.map(&:id),
          invoice_class:   "ClientInvoice",
          idempotency_key: "test-idem-001"
        }
      }
    end

    it "returns 201 and creates a batch" do
      post "/api/v1/batch_arca_processes", params: valid_params, headers: headers, as: :json
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("pending")
      expect(body["total_invoices"]).to eq(3)
    end

    it "enqueues a BatchArcaProcessJob" do
      expect {
        post "/api/v1/batch_arca_processes", params: valid_params, headers: headers, as: :json
      }.to have_enqueued_job(BatchArcaProcessJob)
    end

    context "when idempotency_key was already used" do
      before do
        post "/api/v1/batch_arca_processes", params: valid_params, headers: headers, as: :json
      end

      it "returns the existing batch without creating a new one" do
        expect {
          post "/api/v1/batch_arca_processes", params: valid_params, headers: headers, as: :json
        }.not_to change(BatchArcaProcess, :count)
        expect(response).to have_http_status(:created)
      end
    end

    context "when invoices have mixed sell points" do
      let(:other_sell_point) { create(:sell_point, user: user) }
      let(:mixed_invoices) do
        [
          create(:client_invoice, user: user, sell_point: sell_point,       client: client, invoice_type: "C"),
          create(:client_invoice, user: user, sell_point: other_sell_point, client: client, invoice_type: "C")
        ]
      end

      it "returns 422 with descriptive error" do
        post "/api/v1/batch_arca_processes",
             params: { batch_arca_process: { invoice_ids: mixed_invoices.map(&:id), invoice_class: "ClientInvoice", idempotency_key: "x" } },
             headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_batch")
      end
    end

    context "when not authenticated" do
      it "returns 401" do
        post "/api/v1/batch_arca_processes", params: valid_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/batch_arca_processes/:id" do
    let(:batch) do
      b = create(:batch_arca_process, user: user, sell_point: sell_point,
                 invoice_type: "C", total_invoices: 3, status: :processing)
      invoices.each { |inv| create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv) }
      b
    end

    it "returns the batch with invoices array" do
      get "/api/v1/batch_arca_processes/#{batch.id}", headers: headers
      body = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(body["id"]).to eq(batch.id)
      expect(body["invoices"].length).to eq(3)
      first_invoice_json = body["invoices"].first
      expect(first_invoice_json).to include("number", "arca_status", "client_name")
      expect(first_invoice_json["id"]).to eq(invoices.min_by { |i| i.number.to_i }.id)
      expect(first_invoice_json["number"]).to eq(invoices.min_by { |i| i.number.to_i }.number)
    end

    it "returns 403 for another user's batch" do
      other_user  = create(:user)
      other_batch = create(:batch_arca_process, user: other_user,
                           sell_point: create(:sell_point, user: other_user))
      get "/api/v1/batch_arca_processes/#{other_batch.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/batch_arca_processes/:id/retry" do
    let(:failed_invoice)  { invoices[1] }
    let(:blocked_invoice) { invoices[2] }

    let(:batch) do
      b = create(:batch_arca_process, user: user, sell_point: sell_point,
                 invoice_type: "C", total_invoices: 3, status: :failed)
      create(:batch_arca_process_invoice, batch_arca_process: b, invoice: invoices[0], arca_status: :authorized)
      create(:batch_arca_process_invoice, batch_arca_process: b, invoice: failed_invoice,  arca_status: :failed, arca_error: "Error ARCA")
      create(:batch_arca_process_invoice, batch_arca_process: b, invoice: blocked_invoice, arca_status: :blocked)
      b
    end

    it "creates a new batch with failed + blocked invoices" do
      batch_id = batch.id  # force evaluation before measuring count
      expect {
        post "/api/v1/batch_arca_processes/#{batch_id}/retry",
             params: { idempotency_key: "retry-idem-001" },
             headers: headers, as: :json
      }.to change(BatchArcaProcess, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["parent_batch_id"]).to eq(batch.id)
      expect(body["total_invoices"]).to eq(2)
    end

    it "returns 403 when batch is not retryable" do
      batch.update!(status: :completed)
      post "/api/v1/batch_arca_processes/#{batch.id}/retry",
           params: { idempotency_key: "retry-idem-002" },
           headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/batch_arca_processes" do
    let!(:standalone_batch)    { create(:batch_arca_process, user: user, sell_point: sell_point, invoice_type: "C") }
    let!(:superseded_original) { create(:batch_arca_process, user: user, sell_point: sell_point, invoice_type: "C") }
    let!(:retry_child)         { create(:batch_arca_process, user: user, sell_point: sell_point, invoice_type: "C", parent_batch_id: superseded_original.id) }
    let!(:other_user_batch) do
      other_user = create(:user)
      create(:batch_arca_process, user: other_user, sell_point: create(:sell_point, user: other_user))
    end
    let!(:all_failed_batch) do
      inv = create(:client_invoice, user: user, sell_point: sell_point, client: client, invoice_type: "C")
      b   = create(:batch_arca_process, user: user, sell_point: sell_point, invoice_type: "C",
                   total_invoices: 1, failed_invoices: 1, status: :failed)
      create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv, arca_status: :failed)
      b
    end

    it "returns only the current user's non-superseded batches" do
      get "/api/v1/batch_arca_processes", headers: headers
      body = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(body["data"].length).to eq(2)
    end

    it "excludes superseded batches by default" do
      get "/api/v1/batch_arca_processes", headers: headers
      ids = JSON.parse(response.body)["data"].map { |b| b["id"] }
      expect(ids).to include(standalone_batch.id, retry_child.id)
      expect(ids).not_to include(superseded_original.id)
    end

    it "includes superseded batches when include_retried=true" do
      get "/api/v1/batch_arca_processes?include_retried=true", headers: headers
      body = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(body["data"].length).to eq(3)
    end

    it "excludes batches where all invoices failed" do
      get "/api/v1/batch_arca_processes", headers: headers
      ids = JSON.parse(response.body)["data"].map { |b| b["id"] }
      expect(ids).not_to include(all_failed_batch.id)
    end
  end
end
