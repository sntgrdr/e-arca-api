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

    it 'returns paginated invoices' do
      get '/api/v1/client_invoices', headers: headers, as: :json
      expect(response).to have_http_status(:ok)
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

  describe 'GET /api/v1/client_invoices/:id/download_pdf' do
    let(:invoice) { create(:client_invoice, user: user, client: client, sell_point: sell_point, cae: nil) }

    it 'returns error when no CAE' do
      get "/api/v1/client_invoices/#{invoice.id}/download_pdf", headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
