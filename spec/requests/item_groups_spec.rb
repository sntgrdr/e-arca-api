require 'rails_helper'

RSpec.describe 'Api::V1::ItemGroups', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe 'GET /api/v1/item_groups' do
    before { create_list(:item_group, 3, user: user) }

    it 'returns only active groups' do
      create(:item_group, user: user, active: false)
      get '/api/v1/item_groups', headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(3)
      expect(body.all? { |g| g['active'] == true }).to be true
    end
  end

  describe 'GET /api/v1/item_groups/:id' do
    let(:group) { create(:item_group, user: user) }

    it 'returns the item group' do
      get "/api/v1/item_groups/#{group.id}", headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['name']).to eq(group.name)
    end
  end

  describe 'POST /api/v1/item_groups' do
    it 'creates an item group' do
      post '/api/v1/item_groups',
           params: { item_group: { name: 'Servicios', active: true } },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['name']).to eq('Servicios')
    end

    it 'returns errors for invalid data' do
      post '/api/v1/item_groups',
           params: { item_group: { name: '' } },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns errors for duplicate name within same user' do
      create(:item_group, user: user, name: 'Servicios')
      post '/api/v1/item_groups',
           params: { item_group: { name: 'Servicios' } },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/item_groups/:id' do
    let(:group) { create(:item_group, user: user, name: 'Old Name') }

    it 'updates the item group' do
      patch "/api/v1/item_groups/#{group.id}",
            params: { item_group: { name: 'New Name' } },
            headers: headers,
            as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['name']).to eq('New Name')
    end
  end

  describe 'DELETE /api/v1/item_groups/:id' do
    let(:group) { create(:item_group, user: user) }

    it 'destroys the item group' do
      delete "/api/v1/item_groups/#{group.id}", headers: headers, as: :json
      expect(response).to have_http_status(:no_content)
      expect(ItemGroup.find_by(id: group.id)).to be_nil
    end
  end

  it_behaves_like 'a user-scoped resource' do
    let(:resource_path) { '/api/v1/item_groups' }
    let(:resource)      { create(:item_group, user: user_a) }
    let(:resource_list) { create_list(:item_group, 2, user: user_a) }
  end
end
