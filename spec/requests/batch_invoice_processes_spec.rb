# frozen_string_literal: true

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
               error_details: [ { client_id: 1, error: 'AFIP timeout' } ])
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
