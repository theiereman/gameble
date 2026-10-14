require "test_helper"
require_relative "../support/steam_sign_in"

# The sign-in throttle (config/initializers/rack_attack.rb): 10 sign-in
# requests a minute per IP across POST /auth/steam, the callback and the
# failure endpoint; page reads are never throttled.
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

  test "page reads are never throttled" do
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
end
