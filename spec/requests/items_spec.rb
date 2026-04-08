require 'rails_helper'

RSpec.describe 'Api::V1::Items', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva) { create(:iva, user: user) }

  describe 'GET /api/v1/items' do
    before { create_list(:item, 3, user: user, iva: iva) }

    it 'returns paginated items' do
      get '/api/v1/items', headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end
  end

  describe 'GET /api/v1/items/autocomplete' do
    before { create(:item, user: user, iva: iva, name: 'Servicio Mensual', code: 'SERV01') }

    it 'searches by name' do
      get '/api/v1/items/autocomplete', params: { q: 'serv' }, headers: headers.merge('Accept' => 'application/json')
      expect(response).to have_http_status(:ok)
      results = JSON.parse(response.body)
      expect(results.length).to eq(1)
      expect(results.first['name']).to eq('Servicio Mensual')
    end
  end

  describe 'POST /api/v1/items' do
    it 'creates an item' do
      post '/api/v1/items',
           params: { item: { code: 'NEW01', name: 'New Item', price: 100.0, iva_id: iva.id } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
    end
  end
end
