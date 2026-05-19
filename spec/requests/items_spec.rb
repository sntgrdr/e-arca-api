# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Items', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva) { create(:iva, user: user) }

  describe 'GET /api/v1/items' do
    before { create_list(:item, 3, user: user, iva: iva) }

    it 'returns 200' do
      get '/api/v1/items', headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'wraps records under a data key' do
      get '/api/v1/items', headers: headers
      body = JSON.parse(response.body)
      expect(body).to have_key('data')
      expect(body['data'].length).to eq(3)
    end

    it 'returns a meta object with pagination fields' do
      get '/api/v1/items', headers: headers
      meta = JSON.parse(response.body)['meta']
      expect(meta).to include('count', 'page', 'items', 'pages')
      expect(meta['count']).to eq(3)
    end

    it 'respects the page param' do
      create_list(:item, 20, user: user, iva: iva)
      get '/api/v1/items', params: { page: 2 }, headers: headers
      body = JSON.parse(response.body)
      expect(body['meta']['page']).to eq(2)
      expect(body['data'].length).to be > 0
    end

    it 'returns 404 for an out-of-range page' do
      get '/api/v1/items', params: { page: 9999 }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 without auth headers' do
      get '/api/v1/items', as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/items/autocomplete' do
    let!(:matching) { create(:item, user: user, iva: iva, name: 'Servicio Mensual', code: 'SERV01') }
    let!(:other)    { create(:item, user: user, iva: iva, name: 'Producto Z', code: 'PROD01') }

    it 'returns matching items with id, code, name' do
      get '/api/v1/items/autocomplete', params: { q: 'serv' }, headers: headers
      expect(response).to have_http_status(:ok)
      results = response.parsed_body
      expect(results.length).to eq(1)
      expect(results.first['name']).to eq('Servicio Mensual')
      expect(results.first['code']).to eq('SERV01')
      expect(results.first).to have_key('id')
      expect(results.first).not_to have_key('unit_price')
      expect(results.first).not_to have_key('iva_percentage')
    end

    it 'returns empty array when q is blank' do
      get '/api/v1/items/autocomplete', params: { q: '' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it 'returns empty array when q is absent' do
      get '/api/v1/items/autocomplete', headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it 'matches by code' do
      get '/api/v1/items/autocomplete', params: { q: 'PROD' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first['name']).to eq('Producto Z')
    end

    it 'returns 401 when unauthenticated' do
      get '/api/v1/items/autocomplete', params: { q: 'serv' }
      expect(response).to have_http_status(:unauthorized)
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
