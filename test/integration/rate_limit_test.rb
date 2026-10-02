require "test_helper"

# The sign-in throttle (config/initializers/rack_attack.rb): 10 sign-in
# requests a minute per IP across POST /auth/steam, the callback and the
# failure endpoint; page reads are never throttled.
class RateLimitTest < ActionDispatch::IntegrationTest
  IP = "203.0.113.7"
  OTHER_IP = "203.0.113.8"

  setup do
    # Rack::Attack counts in windows aligned on the clock minute: a test that
    # crossed a minute boundary would start a fresh count. Freeze the clock
    # just after a minute starts.
    travel_to Time.current.beginning_of_minute + 5.seconds
    @cache_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{accounts_players(:player).steam_id}")
  end

  teardown do
    Rack::Attack.reset!
    Rack::Attack.cache.store = @cache_store
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  # One sign-in request of each kind, in turn.
  def sign_in_request(index, ip: IP)
    case index % 3
    when 0 then post "/auth/steam", params: { origin: "/en" }, env: { "REMOTE_ADDR" => ip }
    when 1 then get "/auth/steam/callback", env: { "REMOTE_ADDR" => ip }
    else get "/auth/failure", params: { message: "invalid_credentials" }, env: { "REMOTE_ADDR" => ip }
    end
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
end
