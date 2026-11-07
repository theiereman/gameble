# The request phase POST /auth/steam is OmniAuth middleware that no controller
# `rate_limit` reaches, so sign-in is throttled here, with the shared pages.
module ClientAddress
  def self.of(request)
    ActionDispatch::Request.new(request.env).remote_ip
  end
end

module RoutedPath
  FORMAT = %r{\.[^/]*\z}

  # OmniAuth matches its paths case-insensitively, so this downcases too.
  def self.of(request)
    ActionDispatch::Journey::Router::Utils.normalize_path(request.path).downcase.sub(FORMAT, "")
  end
end

module SignInThrottle
  LIMIT = 10
  PERIOD = 1.minute
  PATHS = {
    "POST" => %w[/auth/steam],
    "GET" => %w[/auth/steam/callback /auth/failure]
  }.freeze

  LOCALIZED_POST_PAGES = %w[auth/clerk settings/sign-ins settings/steam native/session].freeze

  def self.sign_in?(request)
    path = RoutedPath.of(request)
    PATHS.fetch(request.request_method, []).include?(path) || localized_post?(request, path)
  end

  def self.localized_post?(request, path)
    locale, page = path.delete_prefix("/").split("/", 2)
    request.post? && I18n.available_locales.map(&:to_s).include?(locale) && LOCALIZED_POST_PAGES.include?(page)
  end
end

module PublicReadThrottle
  LIMIT = 120
  PERIOD = 1.minute
  PAGES = %w[cards brothers library roadmap feed].freeze

  def self.public_read?(request)
    return false unless request.get? || request.head?

    locale, page = RoutedPath.of(request).split("/", 4)[1, 2]
    return false unless I18n.available_locales.map(&:to_s).include?(locale)

    page.blank? || PAGES.include?(page)
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
