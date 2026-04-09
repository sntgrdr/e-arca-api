require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  let(:user) { create(:user) }

  describe 'POST /api/v1/auth/sign_in' do
    it 'returns JWT token in Authorization header' do
      post '/api/v1/auth/sign_in',
           params: { user: { email: user.email, password: 'securepassword12' } },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Authorization']).to be_present
      expect(response.headers['Authorization']).to start_with('Bearer ')
    end

    it 'returns 401 with invalid credentials' do
      post '/api/v1/auth/sign_in',
           params: { user: { email: user.email, password: 'wrong' } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/auth/sign_up' do
    it 'creates a new user and returns JWT' do
      post '/api/v1/auth/sign_up',
           params: {
             user: {
               email: 'new@example.com',
               password: 'securepassword12',
               password_confirmation: 'securepassword12',
               legal_name: 'New Company',
               legal_number: '20-12345678-9',
               tax_condition: 'registered'
             }
           },
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.headers['Authorization']).to be_present
    end
  end

  describe 'DELETE /api/v1/auth/sign_out' do
    it 'revokes the JWT token' do
      headers = auth_headers(user)

      delete '/api/v1/auth/sign_out', headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'unauthenticated access' do
    it 'returns 401 for protected endpoints' do
      get '/api/v1/clients', as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
