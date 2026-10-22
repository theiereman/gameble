require "test_helper"
require_relative "../support/steam_sign_in"

# The throttles of config/initializers/rack_attack.rb.
class RateLimitTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  IP = "203.0.113.7"
  OTHER_IP = "203.0.113.8"
  LOCAL_PROXY = "172.18.0.3"
  CLOUDFLARE_EDGE = "162.158.12.34"
  CLOUDFLARE_EDGE_V6 = "2606:4700:10::6816:1234"
  OUTSIDE_CLOUDFLARE = "198.51.100.9"

  setup do
    # Rack::Attack counts in windows aligned on the clock minute: a test that
    # crossed a minute boundary would start a fresh count. Freeze the clock
    # just after a minute starts.
    travel_to Time.current.beginning_of_minute + 5.seconds
    @cache_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    mock_steam_sign_in(accounts_players(:player).steam_id)
  end

  teardown do
    Rack::Attack.reset!
    Rack::Attack.cache.store = @cache_store
  end

  # One sign-in request of each kind, in turn.
  def sign_in_request(index, ip: IP, forwarded_for: nil)
    env = { "REMOTE_ADDR" => ip }
    env["HTTP_X_FORWARDED_FOR"] = forwarded_for if forwarded_for
    case index % 3
    when 0 then post "/auth/steam", params: { origin: "/en" }, env: env
    when 1 then get "/auth/steam/callback", env: env
    else get "/auth/failure", params: { message: "invalid_credentials" }, env: env
    end
  end

  def exhaust_public_reads(ip)
    PublicReadThrottle::LIMIT.times { Rack::Attack.cache.count("public-read/ip:#{ip}", PublicReadThrottle::PERIOD) }
  end

  # What the app sees behind Cloudflare: the client, then the Cloudflare
  # edge, forwarded by the local proxies.
  def through_cloudflare(index, client:, edge: CLOUDFLARE_EDGE)
    sign_in_request(index, ip: LOCAL_PROXY, forwarded_for: "#{client}, #{edge}")
  end

  test "Rack::Attack runs before OmniAuth" do
    middlewares = Rails.application.middleware.map(&:klass)

    assert_operator middlewares.index(Rack::Attack), :<, middlewares.index(OmniAuth::Builder)
    assert_equal 1, middlewares.count(Rack::Attack)
  end

  test "ten sign-in requests from one IP within a minute are each handled" do
    10.times do |index|
      sign_in_request(index)

      assert_not_equal 429, response.status, "request #{index + 1}"
    end
  end

  test "the eleventh sign-in request from that IP within the minute gets 429" do
    10.times { |index| sign_in_request(index) }

    post "/auth/steam", params: { origin: "/en" }, env: { "REMOTE_ADDR" => IP }

    assert_response :too_many_requests
    assert_equal "text/plain; charset=utf-8", response.headers["content-type"]
    assert_equal I18n.t("rate_limit.throttled", locale: :en), response.body
    assert response.headers["retry-after"].to_i.between?(1, 60)
  end

  test "each sign-in endpoint is throttled once the IP is over the limit" do
    10.times { |index| sign_in_request(index) }

    3.times do |index|
      sign_in_request(index)

      assert_response :too_many_requests
    end
  end

  test "case-variant sign-in paths count toward the same limit" do
    9.times do |index|
      case index % 3
      when 0 then post "/AUTH/STEAM", params: { origin: "/en" }, env: { "REMOTE_ADDR" => IP }
      when 1 then get "/Auth/Steam/Callback", env: { "REMOTE_ADDR" => IP }
      else get "/AUTH/Failure/", env: { "REMOTE_ADDR" => IP }
      end

      assert_not_equal 429, response.status, "request #{index + 1}"
    end
    sign_in_request(0)
    assert_not_equal 429, response.status

    get "/Auth/Steam/Callback", env: { "REMOTE_ADDR" => IP }

    assert_response :too_many_requests
  end

  test "another IP is handled normally meanwhile" do
    11.times { |index| sign_in_request(index) }
    assert_response :too_many_requests

    sign_in_request(0, ip: OTHER_IP)

    assert_response :redirect
  end

  test "the limit lifts after the minute" do
    11.times { |index| sign_in_request(index) }
    assert_response :too_many_requests

    travel 1.minute do
      sign_in_request(0)

      assert_response :redirect
    end
  end

  test "other page reads are never throttled" do
    10.times { |index| sign_in_request(index) }

    30.times do
      get "/fr", env: { "REMOTE_ADDR" => IP }

      assert_response :success
    end
  end

  test "two clients behind the same Cloudflare edge are counted apart" do
    11.times { |index| through_cloudflare(index, client: IP) }
    assert_response :too_many_requests

    through_cloudflare(0, client: OTHER_IP)

    assert_response :redirect
  end

  test "a client behind an IPv6 Cloudflare edge is counted under its own address" do
    10.times { |index| through_cloudflare(index, client: IP, edge: CLOUDFLARE_EDGE_V6) }
    through_cloudflare(0, client: OTHER_IP, edge: CLOUDFLARE_EDGE_V6)
    assert_response :redirect

    through_cloudflare(1, client: IP, edge: CLOUDFLARE_EDGE_V6)

    assert_response :too_many_requests
  end

  test "a client outside Cloudflare cannot choose its address with the header" do
    11.times do |index|
      sign_in_request(index, ip: LOCAL_PROXY, forwarded_for: "203.0.113.#{100 + index}, #{OUTSIDE_CLOUDFLARE}")
    end

    assert_response :too_many_requests
  end

  test "the 121st read of the shared pages from one address within a minute gets 429, in the page's locale" do
    PublicReadThrottle::LIMIT.times do |index|
      get "/fr/library", env: { "REMOTE_ADDR" => IP }

      assert_not_equal 429, response.status, "read #{index + 1}"
    end

    get "/fr/library", env: { "REMOTE_ADDR" => IP }

    assert_response :too_many_requests
    assert_equal I18n.t("rate_limit.reading_throttled", locale: :fr), response.body
    assert response.headers["retry-after"].to_i.between?(1, 60)
  end

  test "every card's grid is a shared page: the 121st read from one address within a minute gets 429, and no read is cached for other visitors" do
    PublicReadThrottle::LIMIT.times do |index|
      get "/fr/library/cards", env: { "REMOTE_ADDR" => IP }

      assert_not_equal 429, response.status, "read #{index + 1}"
      assert_includes response.headers["cache-control"], "private" if index.zero?
    end

    get "/fr/library/cards", env: { "REMOTE_ADDR" => IP }

    assert_response :too_many_requests
  end

  test "the activity feed is a shared page: the 121st read from one address within a minute gets 429" do
    PublicReadThrottle::LIMIT.times do |index|
      get "/fr/feed", env: { "REMOTE_ADDR" => IP }

      assert_not_equal 429, response.status, "read #{index + 1}"
    end

    get "/fr/feed", env: { "REMOTE_ADDR" => IP }

    assert_response :too_many_requests
    assert_equal I18n.t("rate_limit.reading_throttled", locale: :fr), response.body
  end

  test "another address reads the shared pages meanwhile" do
    exhaust_public_reads(IP)
    get "/en/library/cards", env: { "REMOTE_ADDR" => IP }
    assert_response :too_many_requests

    get "/en/library/cards", env: { "REMOTE_ADDR" => OTHER_IP }

    assert_response :success
  end

  test "a shared page is never cached for other visitors" do
    get "/en/library/cards", env: { "REMOTE_ADDR" => IP }

    assert_response :success
    assert_includes response.headers["cache-control"], "private"
  end

  test "a throttled read of a frame gets that frame back with the message" do
    exhaust_public_reads(IP)

    get "/en/library", params: { q: "hades" }, headers: { "Turbo-Frame" => "collection-results" }, env: { "REMOTE_ADDR" => IP }

    assert_response :too_many_requests
    assert_equal "text/html", response.media_type
    assert_select "turbo-frame#collection-results p", text: I18n.t("rate_limit.reading_throttled", locale: :en)
  end

  test "pages outside the shared ones are read while the shared ones are throttled" do
    exhaust_public_reads(IP)
    get "/en/library", env: { "REMOTE_ADDR" => IP }
    assert_response :too_many_requests

    get "/en/how-it-works", env: { "REMOTE_ADDR" => IP }

    assert_response :success
  end

  test "the shared pages are counted on GET and HEAD, with or without a format, and nothing else is" do
    read = ->(method, path) { PublicReadThrottle.public_read?(Rack::Request.new(Rack::MockRequest.env_for(path, method:))) }

    %w[/fr/cards/hades /en/brothers/abc /en/brothers/abc/library/theme/roguelike /fr/library /fr/library/ /fr/library.html /fr/library/theme/roguelike /en /fr /fr/feed /en/feed.html].each do |path|
      assert read.("GET", path), path
    end
    assert read.("HEAD", "/fr/cards/hades")
    assert_not read.("POST", "/fr/library/seen")
    assert_not read.("POST", "/fr/cards/hades/seasons/1/repost")
    %w[/fr/friends /de/cards/hades /de /fr/cardsx /fr/landing /fr/feedx].each { |path| assert_not read.("GET", path), path }
  end
end
