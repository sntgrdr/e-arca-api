# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::ClientInvoices', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva) { create(:iva, user: user) }
  let(:client) { create(:client, user: user, iva: iva) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:item) { create(:item, user: user, iva: iva) }

  describe 'GET /api/v1/client_invoices' do
    before { create_list(:client_invoice, 3, user: user, client: client, sell_point: sell_point) }

    it 'returns 200' do
      get '/api/v1/client_invoices', headers: headers, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'wraps records under a data key' do
      get '/api/v1/client_invoices', headers: headers, as: :json
      body = JSON.parse(response.body)
      expect(body).to have_key('data')
      expect(body['data'].length).to eq(3)
    end

    it 'returns a meta object with pagination fields' do
      get '/api/v1/client_invoices', headers: headers, as: :json
      meta = JSON.parse(response.body)['meta']
      expect(meta).to include('count', 'page', 'items', 'pages')
      expect(meta['page']).to eq(1)
      expect(meta['count']).to eq(3)
    end

    it 'respects the page param' do
      create_list(:client_invoice, 20, user: user, client: client, sell_point: sell_point)
      get '/api/v1/client_invoices', params: { page: 2 }, headers: headers
      body = JSON.parse(response.body)
      expect(body['meta']['page']).to eq(2)
      expect(body['data'].length).to be > 0
    end

    it 'returns 404 for an out-of-range page' do
      get '/api/v1/client_invoices', params: { page: 9999 }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 without auth headers' do
      get '/api/v1/client_invoices', as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context 'filtered by sell_point_id' do
      let(:other_sell_point) { create(:sell_point, user: user) }

      before do
        create(:client_invoice, user: user, client: client, sell_point: other_sell_point)
      end

      it 'returns only invoices for the given sell_point' do
        get '/api/v1/client_invoices', params: { sell_point_id: sell_point.id }, headers: headers
        body = JSON.parse(response.body)
        expect(body['meta']['count']).to eq(3)
        expect(body['data'].all? { |inv| inv['sell_point']['id'] == sell_point.id }).to be true
      end

      it 'returns empty when no invoices match the sell_point' do
        other_sp = create(:sell_point, user: user)
        get '/api/v1/client_invoices', params: { sell_point_id: other_sp.id }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data']).to be_empty
        expect(body['meta']['count']).to eq(0)
      end
    end
  end

  describe 'GET /api/v1/client_invoices/next_number' do
    it 'returns next invoice number' do
      get '/api/v1/client_invoices/next_number',
          params: { sell_point_id: sell_point.id },
          headers: headers.merge('Accept' => 'application/json')

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['number']).to eq('1')
    end
  end

  describe 'POST /api/v1/client_invoices' do
    it 'creates an invoice with lines' do
      post '/api/v1/client_invoices',
           params: {
             client_invoice: {
               number: '1',
               date: Date.current.to_s,
               period: Date.current.to_s,
               invoice_type: 'C',
               total_price: 1210.0,
               sell_point_id: sell_point.id,
               client_id: client.id,
               lines_attributes: [
                 {
                   item_id: item.id,
                   description: 'Test service',
                   quantity: 1,
                   unit_price: 1000.0,
                   final_price: 1210.0,
                   user_id: user.id,
                   iva_id: iva.id
                 }
               ]
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe 'GET /api/v1/client_invoices/:id' do
    context 'when invoice has no CAE' do
      let(:invoice) { create(:client_invoice, user: user, client: client, sell_point: sell_point) }

      it 'returns can_edit: true' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['can_edit']).to eq(true)
      end

      it 'returns can_send_to_arca: true' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        expect(JSON.parse(response.body)['can_send_to_arca']).to eq(true)
      end

      it 'returns can_create_credit_note: false' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        expect(JSON.parse(response.body)['can_create_credit_note']).to eq(false)
      end

      it 'returns credit_notes as empty array' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        expect(JSON.parse(response.body)['credit_notes']).to eq([])
      end
    end

    context 'when invoice has a CAE (authorized)' do
      let(:invoice) { create(:client_invoice, :with_cae, user: user, client: client, sell_point: sell_point) }

      it 'returns can_edit: false' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        expect(JSON.parse(response.body)['can_edit']).to eq(false)
      end

      it 'returns can_send_to_arca: false' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        expect(JSON.parse(response.body)['can_send_to_arca']).to eq(false)
      end

      it 'returns can_create_credit_note: true' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        expect(JSON.parse(response.body)['can_create_credit_note']).to eq(true)
      end

      context 'with associated credit notes' do
        before { create(:credit_note, user: user, client: client, sell_point: sell_point, client_invoice: invoice) }

        it 'returns credit_notes array with data' do
          get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
          body = JSON.parse(response.body)
          expect(body['credit_notes'].length).to eq(1)
          expect(body['credit_notes'].first).to include('id', 'number', 'date', 'total_price', 'cae')
        end
      end
    end

    context 'with sell_point, client and lines' do
      let(:invoice) { create(:client_invoice, :with_lines, user: user, client: client, sell_point: sell_point) }

      it 'returns sell_point, client and lines' do
        get "/api/v1/client_invoices/#{invoice.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['sell_point']).to include('id', 'number')
        expect(body['client']).to include('id', 'legal_name', 'legal_number', 'tax_condition')
        expect(body['lines']).to be_an(Array)
      end
    end
  end

  describe 'GET /api/v1/client_invoices/:id/download_pdf' do
    let(:invoice) { create(:client_invoice, user: user, client: client, sell_point: sell_point, cae: nil) }

    it 'returns error when no CAE' do
      get "/api/v1/client_invoices/#{invoice.id}/download_pdf", headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
