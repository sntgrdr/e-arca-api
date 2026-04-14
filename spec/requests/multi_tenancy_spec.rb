# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multi-tenancy enforcement', type: :request do
  # ------------------------------------------------------------------
  # Clients
  # ------------------------------------------------------------------
  describe 'Clients' do
    it_behaves_like 'a user-scoped resource' do
      let(:iva_a) { create(:iva, user: user_a) }
      let(:resource_path) { '/api/v1/clients' }
      let(:resource) { create(:client, user: user_a, iva: iva_a) }
      let(:resource_list) { create_list(:client, 2, user: user_a, iva: iva_a) }
    end
  end

  # ------------------------------------------------------------------
  # Client Groups
  # ------------------------------------------------------------------
  describe 'Client Groups' do
    it_behaves_like 'a user-scoped resource' do
      let(:resource_path) { '/api/v1/client_groups' }
      let(:resource) { create(:client_group, user: user_a) }
      let(:resource_list) { create_list(:client_group, 2, user: user_a) }
    end
  end

  # ------------------------------------------------------------------
  # Items
  # ------------------------------------------------------------------
  describe 'Items' do
    it_behaves_like 'a user-scoped resource' do
      let(:iva_a) { create(:iva, user: user_a) }
      let(:resource_path) { '/api/v1/items' }
      let(:resource) { create(:item, user: user_a, iva: iva_a) }
      let(:resource_list) { create_list(:item, 2, user: user_a, iva: iva_a) }
    end
  end

  # ------------------------------------------------------------------
  # IVAs
  # ------------------------------------------------------------------
  describe 'IVAs' do
    it_behaves_like 'a user-scoped resource' do
      let(:resource_path) { '/api/v1/ivas' }
      let(:resource) { create(:iva, user: user_a) }
      let(:resource_list) { create_list(:iva, 2, user: user_a) }
    end
  end

  # ------------------------------------------------------------------
  # Sell Points
  # ------------------------------------------------------------------
  describe 'Sell Points' do
    it_behaves_like 'a user-scoped resource' do
      let(:resource_path) { '/api/v1/sell_points' }
      let(:resource) { create(:sell_point, user: user_a) }
      let(:resource_list) { create_list(:sell_point, 2, user: user_a) }
    end
  end

  # ------------------------------------------------------------------
  # Client Invoices
  # ------------------------------------------------------------------
  describe 'Client Invoices' do
    it_behaves_like 'a user-scoped resource' do
      let(:iva_a) { create(:iva, user: user_a) }
      let(:client_a) { create(:client, user: user_a, iva: iva_a) }
      let(:sell_point_a) { create(:sell_point, user: user_a) }
      let(:resource_path) { '/api/v1/client_invoices' }
      let(:resource) { create(:client_invoice, user: user_a, client: client_a, sell_point: sell_point_a) }
      let(:resource_list) { create_list(:client_invoice, 2, user: user_a, client: client_a, sell_point: sell_point_a) }
    end

    describe 'send_to_arca' do
      it_behaves_like 'a user-scoped member action' do
        let(:iva_a) { create(:iva, user: user_a) }
        let(:client_a) { create(:client, user: user_a, iva: iva_a) }
        let(:sell_point_a) { create(:sell_point, user: user_a) }
        let(:resource_path) { '/api/v1/client_invoices' }
        let(:resource) { create(:client_invoice, user: user_a, client: client_a, sell_point: sell_point_a) }
        let(:action_name) { 'send_to_arca' }
        let(:http_method) { :post }
      end
    end

    describe 'download_pdf' do
      it_behaves_like 'a user-scoped member action' do
        let(:iva_a) { create(:iva, user: user_a) }
        let(:client_a) { create(:client, user: user_a, iva: iva_a) }
        let(:sell_point_a) { create(:sell_point, user: user_a) }
        let(:resource_path) { '/api/v1/client_invoices' }
        let(:resource) { create(:client_invoice, user: user_a, client: client_a, sell_point: sell_point_a) }
        let(:action_name) { 'download_pdf' }
        let(:http_method) { :get }
      end
    end
  end

  # ------------------------------------------------------------------
  # Credit Notes
  # ------------------------------------------------------------------
  describe 'Credit Notes' do
    it_behaves_like 'a user-scoped resource' do
      let(:iva_a) { create(:iva, user: user_a) }
      let(:client_a) { create(:client, user: user_a, iva: iva_a) }
      let(:sell_point_a) { create(:sell_point, user: user_a) }
      let(:invoice_a) { create(:client_invoice, :with_cae, user: user_a, client: client_a, sell_point: sell_point_a) }
      let(:resource_path) { '/api/v1/credit_notes' }
      let(:resource) { create(:credit_note, user: user_a, client: client_a, sell_point: sell_point_a, client_invoice: invoice_a) }
      let(:resource_list) { create_list(:credit_note, 2, user: user_a, client: client_a, sell_point: sell_point_a, client_invoice: invoice_a) }
    end

    describe 'send_to_arca' do
      it_behaves_like 'a user-scoped member action' do
        let(:iva_a) { create(:iva, user: user_a) }
        let(:client_a) { create(:client, user: user_a, iva: iva_a) }
        let(:sell_point_a) { create(:sell_point, user: user_a) }
        let(:invoice_a) { create(:client_invoice, :with_cae, user: user_a, client: client_a, sell_point: sell_point_a) }
        let(:resource_path) { '/api/v1/credit_notes' }
        let(:resource) { create(:credit_note, user: user_a, client: client_a, sell_point: sell_point_a, client_invoice: invoice_a) }
        let(:action_name) { 'send_to_arca' }
        let(:http_method) { :post }
      end
    end

    describe 'download_pdf' do
      it_behaves_like 'a user-scoped member action' do
        let(:iva_a) { create(:iva, user: user_a) }
        let(:client_a) { create(:client, user: user_a, iva: iva_a) }
        let(:sell_point_a) { create(:sell_point, user: user_a) }
        let(:invoice_a) { create(:client_invoice, :with_cae, user: user_a, client: client_a, sell_point: sell_point_a) }
        let(:resource_path) { '/api/v1/credit_notes' }
        let(:resource) { create(:credit_note, user: user_a, client: client_a, sell_point: sell_point_a, client_invoice: invoice_a) }
        let(:action_name) { 'download_pdf' }
        let(:http_method) { :get }
      end
    end
  end

  # ------------------------------------------------------------------
  # Batch Invoice Processes (only index, show, create — no update/delete)
  # ------------------------------------------------------------------
  describe 'Batch Invoice Processes' do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }
    let(:headers_b) { auth_headers(user_b) }
    let(:iva_a) { create(:iva, user: user_a) }
    let(:item_a) { create(:item, user: user_a, iva: iva_a) }
    let(:sell_point_a) { create(:sell_point, user: user_a) }

    let(:batch_process) do
      create(:batch_invoice_process, user: user_a, item: item_a, sell_point: sell_point_a)
    end

    let(:batch_process_list) do
      create_list(:batch_invoice_process, 2, user: user_a, item: item_a, sell_point: sell_point_a)
    end

    describe 'cross-user show' do
      it 'returns 404 when User B tries to GET User A batch process' do
        batch_process
        get "/api/v1/batch_invoice_processes/#{batch_process.id}", headers: headers_b, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'cross-user index isolation' do
      it 'does not include User A batch processes in User B index' do
        batch_process_list
        get '/api/v1/batch_invoice_processes', headers: headers_b, as: :json
        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        records = body.is_a?(Array) ? body : (body['data'] || [])
        resource_ids = records.map { |r| r['id'] }
        owner_ids = batch_process_list.map(&:id)

        expect(resource_ids & owner_ids).to be_empty
      end
    end

    describe 'generate_pdfs' do
      it 'returns 404 when User B tries to generate PDFs for User A batch process' do
        batch_process
        post "/api/v1/batch_invoice_processes/#{batch_process.id}/generate_pdfs",
             headers: headers_b, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'download_pdfs' do
      it 'returns 404 when User B tries to download PDFs for User A batch process' do
        batch_process
        get "/api/v1/batch_invoice_processes/#{batch_process.id}/download_pdfs",
            headers: headers_b, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
