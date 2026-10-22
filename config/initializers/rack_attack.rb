# The request phase POST /auth/steam is OmniAuth middleware that no controller
# `rate_limit` reaches, so sign-in is throttled here, with the shared pages.
module ClientAddress
  def self.of(request)
    ActionDispatch::Request.new(request.env).remote_ip
  end
end

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
end

module PublicReadThrottle
  LIMIT = 120
  PERIOD = 1.minute
  PAGES = %w[cards brothers library landing roadmap feed].freeze

  def self.public_read?(request)
    return false unless request.get? || request.head?

    locale, page = request.path.split("/", 4)[1, 2]
    I18n.available_locales.map(&:to_s).include?(locale) && PAGES.include?(page.to_s.split(".").first)
  end
end

Rack::Attack.cache.store = Rails.cache

Rack::Attack.throttle("sign-in/ip", limit: SignInThrottle::LIMIT, period: SignInThrottle::PERIOD) do |request|
  ClientAddress.of(request) if SignInThrottle.sign_in?(request)
end

Rack::Attack.throttle("public-read/ip", limit: PublicReadThrottle::LIMIT, period: PublicReadThrottle::PERIOD) do |request|
  ClientAddress.of(request) if PublicReadThrottle.public_read?(request)
end

# A throttled Turbo Frame request gets its frame back, or Turbo shows "Content missing".
Rack::Attack.throttled_responder = lambda do |request|
  match = request.env["rack.attack.match_data"] || {}
  period = match[:period] || SignInThrottle::PERIOD.to_i
  retry_after = period - (Time.now.to_i % period)
  locale = request.path[%r{\A/([^/]+)/}, 1]
  locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale)
  key = request.env["rack.attack.matched"] == "public-read/ip" ? "rate_limit.reading_throttled" : "rate_limit.throttled"
  message = I18n.t(key, locale:)
  headers = { "retry-after" => retry_after.to_s }

  if (frame = request.env["HTTP_TURBO_FRAME"].presence)
    body = %(<turbo-frame id="#{ERB::Util.html_escape(frame)}"><p>#{ERB::Util.html_escape(message)}</p></turbo-frame>)
    [ 429, headers.merge("content-type" => "text/html; charset=utf-8"), [ body ] ]
  else
    [ 429, headers.merge("content-type" => "text/plain; charset=utf-8"), [ message ] ]
  end
end

# The Rack::Attack railtie appends it to the stack; it must run before
# OmniAuth::Builder, which answers POST /auth/steam itself
# (test/integration/rate_limit_test.rb asserts the order).
Rails.application.config.middleware.move_before OmniAuth::Builder, Rack::Attack
