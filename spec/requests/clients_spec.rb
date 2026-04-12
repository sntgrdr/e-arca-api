require 'rails_helper'

RSpec.describe 'Api::V1::Clients', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva) { create(:iva, user: user) }

  describe 'GET /api/v1/clients' do
    before { create_list(:client, 3, user: user, iva: iva) }

    it 'returns paginated clients' do
      get '/api/v1/clients', headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end

    it 'returns client_group_name as null when client has no group' do
      get '/api/v1/clients', headers: headers, as: :json
      body = JSON.parse(response.body)
      expect(body.first['client_group_name']).to be_nil
    end

    context 'when client belongs to a group' do
      let(:group) { create(:client_group, user: user) }

      before { create(:client, user: user, iva: iva, client_group: group) }

      it 'returns client_group_name' do
        get '/api/v1/clients', headers: headers, as: :json
        body = JSON.parse(response.body)
        client_with_group = body.find { |c| c['client_group_id'] == group.id }
        expect(client_with_group['client_group_name']).to eq(group.name)
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

  describe 'DELETE /api/v1/clients/:id' do
    let!(:client) { create(:client, user: user, iva: iva) }

    it 'deletes the client' do
      expect {
        delete "/api/v1/clients/#{client.id}", headers: headers, as: :json
      }.to change(Client, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
