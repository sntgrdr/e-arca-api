module AuthHelper
  def auth_headers(user)
    post '/api/v1/auth/sign_in',
         params: { user: { email: user.email, password: 'securepassword12' } },
         as: :json

    # JWT is now in an HTTP-only cookie — pass it as a Cookie header
    token = response.cookies[JwtCookieMiddleware::COOKIE_NAME]
    { 'Cookie' => "#{JwtCookieMiddleware::COOKIE_NAME}=#{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
