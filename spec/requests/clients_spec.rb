# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Clients', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva) { create(:iva, user: user) }

  describe 'GET /api/v1/clients' do
    before { create_list(:client, 3, user: user, iva: iva) }

    it 'returns 200' do
      get '/api/v1/clients', headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'wraps records under a data key' do
      get '/api/v1/clients', headers: headers
      body = JSON.parse(response.body)
      expect(body).to have_key('data')
      expect(body['data'].length).to eq(3)
    end

    it 'returns a meta object with pagination fields' do
      get '/api/v1/clients', headers: headers
      meta = JSON.parse(response.body)['meta']
      expect(meta).to include('count', 'page', 'items', 'pages')
      expect(meta['page']).to eq(1)
      expect(meta['count']).to eq(3)
    end

    it 'respects the page param' do
      create_list(:client, 20, user: user, iva: iva)  # 23 total
      get '/api/v1/clients', params: { page: 2 }, headers: headers
      body = JSON.parse(response.body)
      expect(body['meta']['page']).to eq(2)
      expect(body['data'].length).to be > 0
    end

    it 'returns 404 for an out-of-range page' do
      get '/api/v1/clients', params: { page: 9999 }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns client_group_name as null when client has no group' do
      get '/api/v1/clients', headers: headers
      body = JSON.parse(response.body)
      expect(body['data'].first['client_group_name']).to be_nil
    end

    context 'when client belongs to a group' do
      let(:group) { create(:client_group, user: user) }

      before { create(:client, user: user, iva: iva, client_group: group) }

      it 'returns client_group_name' do
        get '/api/v1/clients', headers: headers
        body = JSON.parse(response.body)
        client_with_group = body['data'].find { |c| c['client_group_id'] == group.id }
        expect(client_with_group['client_group_name']).to eq(group.name)
      end
    end
  end

  describe 'GET /api/v1/clients — server-side filtering' do
    let(:other_user) { create(:user) }
    let(:other_iva)  { create(:iva, user: other_user) }

    before do
      create(:client, user: user, iva: iva, legal_name: 'García Hermanos',   name: 'García Hnos',  legal_number: '20304567890', tax_condition: :registered)
      create(:client, user: user, iva: iva, legal_name: 'López Consultores', name: 'López & Asoc', legal_number: '27123456789', tax_condition: :self_employed)
      create(:client, user: user, iva: iva, legal_name: 'Unrelated SA',      name: 'Unrelated',    legal_number: '30999999990', tax_condition: :exempt)
    end

    describe 'q param' do
      it 'filters by legal_name (case-insensitive partial)' do
        get '/api/v1/clients', params: { q: 'GARCÍA' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to include('García Hermanos')
        expect(body['data'].map { |c| c['legal_name'] }).not_to include('López Consultores')
        expect(body['meta']['count']).to eq(1)
      end

      it 'filters by commercial name (name field)' do
        get '/api/v1/clients', params: { q: 'López & Asoc' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to include('López Consultores')
        expect(body['meta']['count']).to eq(1)
      end

      it 'returns all when q is blank' do
        get '/api/v1/clients', params: { q: '' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['meta']['count']).to eq(3)
      end
    end

    describe 'legal_number param' do
      it 'matches partial CUIT (digits only stored)' do
        get '/api/v1/clients', params: { legal_number: '20304' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to contain_exactly('García Hermanos')
      end

      it 'normalizes dashes in the search term' do
        get '/api/v1/clients', params: { legal_number: '20-304-567' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to include('García Hermanos')
      end
    end

    describe 'tax_condition param' do
      it 'returns only clients with matching tax_condition' do
        get '/api/v1/clients', params: { tax_condition: 'self_employed' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to contain_exactly('López Consultores')
        expect(body['meta']['count']).to eq(1)
      end

      it 'returns 422 for an unknown tax_condition value' do
        get '/api/v1/clients', params: { tax_condition: 'invalid_value' }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).dig('error', 'code')).to eq('invalid_param')
      end
    end

    describe 'client_group_id param' do
      let(:group) { create(:client_group, user: user) }

      before { create(:client, user: user, iva: iva, legal_name: 'Grouped Client', legal_number: '20111111110', tax_condition: :registered, client_group: group) }

      it 'returns only clients in the given group' do
        get '/api/v1/clients', params: { client_group_id: group.id }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to contain_exactly('Grouped Client')
      end

      it 'returns empty when client_group_id belongs to another user' do
        other_group = create(:client_group, user: other_user)
        get '/api/v1/clients', params: { client_group_id: other_group.id }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data']).to be_empty
        expect(body['meta']['count']).to eq(0)
      end
    end

    describe 'combined filters' do
      let(:group) { create(:client_group, user: user) }

      before { create(:client, user: user, iva: iva, legal_name: 'García Monotributo', legal_number: '20222222220', tax_condition: :self_employed, client_group: group) }

      it 'applies q and tax_condition with AND logic' do
        get '/api/v1/clients', params: { q: 'García', tax_condition: 'self_employed' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to contain_exactly('García Monotributo')
      end

      it 'applies q and client_group_id with AND logic' do
        get '/api/v1/clients', params: { q: 'García', client_group_id: group.id }, headers: headers
        body = JSON.parse(response.body)
        expect(body['data'].map { |c| c['legal_name'] }).to contain_exactly('García Monotributo')
      end
    end

    describe 'meta reflects filtered count' do
      it 'returns filtered count not total count in meta' do
        get '/api/v1/clients', params: { q: 'García' }, headers: headers
        body = JSON.parse(response.body)
        expect(body['meta']['count']).to eq(1)
        expect(body['meta']['pages']).to eq(1)
      end
    end
  end

  describe 'POST /api/v1/clients' do
    it 'creates a client' do
      post '/api/v1/clients',
           params: {
             client: {
               legal_name: 'New Client',
               legal_number: '30-99999999-0',
               tax_condition: 'final_client',
               iva_id: iva.id
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['legal_name']).to eq('New Client')
    end

    it 'returns errors for invalid data' do
      post '/api/v1/clients',
           params: { client: { legal_name: '' } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /api/v1/clients/:id' do
    let(:client) { create(:client, user: user, iva: iva) }

    it 'returns the client' do
      get "/api/v1/clients/#{client.id}", headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['id']).to eq(client.id)
    end
  end

  describe 'PATCH /api/v1/clients/:id' do
    let(:client) { create(:client, user: user, iva: iva) }

    it 'updates the client' do
      patch "/api/v1/clients/#{client.id}",
            params: { client: { name: 'Updated' } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['name']).to eq('Updated')
    end
  end

  describe 'GET /api/v1/clients?status=inactive' do
    before do
      create(:client, user: user, iva: iva, active: true)
      create(:client, user: user, iva: iva, active: false)
    end

    it 'returns only inactive clients' do
      get '/api/v1/clients?status=inactive', headers: headers
      body = JSON.parse(response.body)
      expect(body['data'].length).to eq(1)
      expect(body['data'].first['active']).to eq(false)
    end

    it 'returns only active clients by default' do
      get '/api/v1/clients', headers: headers
      body = JSON.parse(response.body)
      expect(body['data'].all? { |c| c['active'] == true }).to eq(true)
    end
  end

  describe 'PATCH /api/v1/clients/:id/deactivate' do
    let!(:client) { create(:client, user: user, iva: iva, active: true) }

    it 'deactivates the client' do
      patch "/api/v1/clients/#{client.id}/deactivate", headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['active']).to eq(false)
    end

    context 'when client is final_client' do
      let!(:final) { create(:client, user: user, iva: iva, active: true, final_client: true, legal_number: '11111111111', legal_name: 'Consumidor Final') }

      it 'returns 422' do
        patch "/api/v1/clients/#{final.id}/deactivate", headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/clients/:id/reactivate' do
    let!(:client) { create(:client, user: user, iva: iva, active: false) }

    it 'reactivates the client' do
      patch "/api/v1/clients/#{client.id}/reactivate", headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['active']).to eq(true)
    end
  end

  describe 'PATCH /api/v1/clients/bulk_deactivate' do
    let!(:clients) { create_list(:client, 3, user: user, iva: iva, active: true) }

    it 'deactivates all matched clients' do
      patch '/api/v1/clients/bulk_deactivate',
            params: { ids: clients.map(&:id) },
            headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['deactivated']).to eq(3)
    end

    it 'returns 0 for foreign ids' do
      other_user = create(:user)
      other_client = create(:client, user: other_user, iva: create(:iva, user: other_user))
      patch '/api/v1/clients/bulk_deactivate',
            params: { ids: [ other_client.id ] },
            headers: headers, as: :json
      expect(JSON.parse(response.body)['deactivated']).to eq(0)
    end

    it 'skips final_client records' do
      final = create(:client, user: user, iva: iva, active: true, final_client: true,
                     legal_number: '11111111111', legal_name: 'Consumidor Final')
      patch '/api/v1/clients/bulk_deactivate',
            params: { ids: [ final.id ] },
            headers: headers, as: :json
      expect(JSON.parse(response.body)['deactivated']).to eq(0)
      expect(final.reload.active).to eq(true)
    end
  end

  describe 'PATCH /api/v1/clients/bulk_reactivate' do
    let!(:clients) { create_list(:client, 2, user: user, iva: iva, active: false) }

    it 'reactivates all matched clients' do
      patch '/api/v1/clients/bulk_reactivate',
            params: { ids: clients.map(&:id) },
            headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['reactivated']).to eq(2)
    end
  end

  describe 'DELETE /api/v1/clients/:id' do
    let!(:client) { create(:client, user: user, iva: iva) }

    it 'deletes the client' do
      expect {
        delete "/api/v1/clients/#{client.id}", headers: headers, as: :json
      }.to change(Client, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'when client is final_client' do
      let!(:final) { create(:client, user: user, iva: iva, final_client: true,
                            legal_number: '11111111111', legal_name: 'Consumidor Final') }

      it 'returns 403' do
        delete "/api/v1/clients/#{final.id}", headers: headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'final_client flag in response' do
    it 'returns final_client in client serializer' do
      client = create(:client, user: user, iva: iva)
      get "/api/v1/clients/#{client.id}", headers: headers, as: :json
      expect(JSON.parse(response.body)).to have_key('final_client')
    end
  end
end
