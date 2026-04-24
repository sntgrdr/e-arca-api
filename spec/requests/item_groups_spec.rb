# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/item_groups', type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }

  before { create_list(:item_group, 3, user: user) }

  it 'returns 200' do
    get '/api/v1/item_groups', headers: headers
    expect(response).to have_http_status(:ok)
  end

  it 'wraps records under a data key' do
    get '/api/v1/item_groups', headers: headers
    body = JSON.parse(response.body)
    expect(body).to have_key('data')
    expect(body['data'].length).to eq(3)
  end

  it 'returns a meta object with pagination fields' do
    get '/api/v1/item_groups', headers: headers
    meta = JSON.parse(response.body)['meta']
    expect(meta).to include('count', 'page', 'items', 'pages')
    expect(meta['count']).to eq(3)
  end

  it 'returns 401 without auth' do
    get '/api/v1/item_groups'
    expect(response).to have_http_status(:unauthorized)
  end
end
