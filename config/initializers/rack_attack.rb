# Sign-in throttle (abuse convention). The request phase POST /auth/steam is
# OmniAuth middleware that no controller `rate_limit` reaches, so the three
# sign-in endpoints are throttled here, per client IP: 10 requests a minute
# across them. Page reads are never throttled. Counts live in Rails.cache.
# The client's address is Rails' remote IP, which looks past Cloudflare
# (config/initializers/trusted_proxies.rb).
module SignInThrottle
  LIMIT = 10
  PERIOD = 1.minute
  PATHS = {
    "POST" => %w[/auth/steam],
    "GET" => %w[/auth/steam/callback /auth/failure]
  }.freeze

  # OmniAuth matches its paths case-insensitively, so this does too.
  def self.sign_in?(request)
    PATHS.fetch(request.request_method, []).include?(request.path.downcase.chomp("/"))
  end

  def self.client_ip(request)
    ActionDispatch::Request.new(request.env).remote_ip
  end
end

Rack::Attack.cache.store = Rails.cache

Rack::Attack.throttle("sign-in/ip", limit: SignInThrottle::LIMIT, period: SignInThrottle::PERIOD) do |request|
  SignInThrottle.client_ip(request) if SignInThrottle.sign_in?(request)
end

# 429 with a short plain-text body. These paths carry no locale; the default
# one answers.
Rack::Attack.throttled_responder = lambda do |request|
  match = request.env["rack.attack.match_data"] || {}
  period = match[:period] || SignInThrottle::PERIOD.to_i
  retry_after = period - (Time.now.to_i % period)
  body = I18n.t("rate_limit.throttled", locale: I18n.default_locale)

  [ 429, { "content-type" => "text/plain; charset=utf-8", "retry-after" => retry_after.to_s }, [ body ] ]
end

# The Rack::Attack railtie appends it to the stack; it must run before
# OmniAuth::Builder, which answers POST /auth/steam itself
# (test/integration/rate_limit_test.rb asserts the order).
Rails.application.config.middleware.move_before OmniAuth::Builder, Rack::Attack
