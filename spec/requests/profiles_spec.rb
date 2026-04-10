require 'rails_helper'

RSpec.describe 'Api::V1::Profiles', type: :request do
  let(:user) { create(:user, legal_number: '20388864304', dni: '38886430') }
  let(:headers) { auth_headers(user) }

  describe 'GET /api/v1/profile' do
    it 'returns the current user profile including dni' do
      get '/api/v1/profile', headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['email']).to eq(user.email)
      expect(body['legal_number']).to eq(user.legal_number)
      expect(body['dni']).to eq('38886430')
    end
  end

  describe 'PATCH /api/v1/profile' do
    it 'updates basic profile fields' do
      patch '/api/v1/profile',
            params: { user: { name: 'New Name', city: 'Córdoba' } },
            headers: headers,
            as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['name']).to eq('New Name')
      expect(body['city']).to eq('Córdoba')
    end

    it 'updates dni when it matches legal_number' do
      patch '/api/v1/profile',
            params: { user: { dni: '38886430' } },
            headers: headers,
            as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['dni']).to eq('38886430')
    end

    it 'returns errors when dni does not match legal_number' do
      patch '/api/v1/profile',
            params: { user: { dni: '99999999' } },
            headers: headers,
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'updates password when complexity requirements are met' do
      patch '/api/v1/profile',
            params: { user: { password: 'NewSecure.1', password_confirmation: 'NewSecure.1' } },
            headers: headers,
            as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'returns errors for invalid password' do
      patch '/api/v1/profile',
            params: { user: { password: 'weakpassword', password_confirmation: 'weakpassword' } },
            headers: headers,
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
