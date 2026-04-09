module AuthHelper
  def auth_headers(user)
    post '/api/v1/auth/sign_in',
         params: { user: { email: user.email, password: 'securepassword12' } },
         as: :json

    token = response.headers['Authorization']
    { 'Authorization' => token }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
