class JwtCookieMiddleware
  COOKIE_NAME = '_e_arca_jwt'

  def initialize(app)
    @app = app
  end

  def call(env)
    # On request: copy JWT from cookie to Authorization header so devise-jwt can verify it
    if (token = Rack::Request.new(env).cookies[COOKIE_NAME])
      env['HTTP_AUTHORIZATION'] = "Bearer #{token}"
    end

    status, headers, body = @app.call(env)

    # On response: move JWT from Authorization header into an HTTP-only cookie
    if (auth = headers.delete('Authorization'))
      token = auth.sub('Bearer ', '')
      Rack::Utils.set_cookie_header!(headers, COOKIE_NAME, {
        value:     token,
        httponly:  true,
        secure:    Rails.env.production?,
        same_site: :lax,
        path:      '/',
        max_age:   24.hours.to_i
      })
    end

    [status, headers, body]
  end
end
