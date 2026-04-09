class Rack::Attack
  # Use Rails cache as the backing store
  Rack::Attack.cache.store = Rails.cache

  # --- Throttles ---

  # General API: 100 req/min per IP
  throttle("req/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Login: 5 req/20s per email
  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/api/v1/auth/sign_in" && req.post?
      req.params.dig("user", "email")&.downcase&.strip
    end
  end

  # Signup: 3 req/min per IP
  throttle("signups/ip", limit: 3, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth" && req.post?
  end

  # Authenticated API: 300 req/min per user
  throttle("api/user", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/") && req.env["warden"]&.user
      req.env["warden"].user.id
    end
  end

  # --- Blocklists ---

  # Auto-ban IPs scanning for common exploit paths
  blocklist("malicious-scanners") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
      req.path.match?(%r{/(wp-admin|wp-login|\.env|phpmyadmin|phpinfo|cgi-bin|\.git)})
    end
  end

  # --- Response ---

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_s

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after
      },
      [{ error: { code: "rate_limited", message: "Too many requests. Retry after #{retry_after}s" } }.to_json]
    ]
  end
end

# Disable in test environment
Rack::Attack.enabled = !Rails.env.test?
