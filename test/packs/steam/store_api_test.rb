require "test_helper"
require_relative "../../support/steam_api_stubs"

# The Steam store API client (AD-4, AD-19): appdetails in English, its
# malformed answers, the spacing of its requests and its rate limit.
class Steam::StoreApiTest < ActiveSupport::TestCase
  include SteamApiStubs

  setup { stub_steam_api }
  teardown { unstub_steam_api }

  test "app_details asks for one app in US English with its basic data and genres, without a key" do
    calls = stub_app_details(620 => app_details_entry(620))

    entry = Steam::StoreApi.new.app_details(620)

    assert_equal [ { "appids" => "620", "cc" => "us", "l" => "english", "filters" => "basic,genres" } ], calls
    assert_equal app_details_entry(620), entry
  end

  test "app_details returns an unsuccessful entry as it is" do
    stub_app_details({})

    assert_equal({ "success" => false }, Steam::StoreApi.new.app_details(620))
  end

  [ :null, :missing, :not_json ].each do |answer|
    test "app_details raises on a #{answer} answer" do
      stub_app_details(620 => answer)

      assert_raises(Steam::StoreApi::Error) { Steam::StoreApi.new.app_details(620) }
    end
  end

  test "an entry that is not an object raises" do
    steam_stubs.get(APP_DETAILS_PATH) { [ 200, { "Content-Type" => "application/json" }, { "620" => [] }.to_json ] }

    assert_raises(Steam::StoreApi::Error) { Steam::StoreApi.new.app_details(620) }
  end

  [ 429, 403 ].each do |status|
    test "a #{status} is not retried and raises RateLimited at once" do
      calls = 0
      steam_stubs.get(APP_DETAILS_PATH) do
        calls += 1
        [ status, {}, "" ]
      end

      error = assert_raises(Steam::StoreApi::RateLimited) { Steam::StoreApi.new.app_details(620) }

      assert_equal 1, calls
      assert_empty store_sleeps
      assert_includes error.message, status.to_s
      assert_kind_of Steam::StoreApi::Error, error
    end
  end

  test "a 503 then the answer gives the answer" do
    steam_stubs.get(APP_DETAILS_PATH) { [ 503, {}, "" ] }
    stub_app_details(620 => app_details_entry(620))

    assert_equal true, Steam::StoreApi.new.app_details(620)["success"]
  end

  test "a 503 that outlasts the retries raises Error, not RateLimited" do
    calls = 0
    steam_stubs.get(APP_DETAILS_PATH) do
      calls += 1
      [ 503, {}, "" ]
    end

    error = assert_raises(Steam::StoreApi::Error) { Steam::StoreApi.new.app_details(620) }
    assert_not_kind_of Steam::StoreApi::RateLimited, error
    assert_equal 5, calls
  end

  test "a second request waits until the interval has passed since the first, retries included" do
    Steam::StoreApi.interval = 2.0
    statuses = [ 503, 200, 200 ]
    steam_stubs.get(APP_DETAILS_PATH) do |env|
      appid = env.params.fetch("appids")
      [ statuses.shift, { "Content-Type" => "application/json" }, { appid => app_details_entry(appid.to_i) }.to_json ]
    end
    api = Steam::StoreApi.new

    api.app_details(620)
    assert_equal 1, store_sleeps.size, "the retry after the 503 is spaced"
    api.app_details(730)

    # The recorder does not sleep: each request is booked `interval` after
    # the previous one, so the waits pile up as the clock stands still.
    assert_equal 2, store_sleeps.size
    assert_in_delta 2.0, store_sleeps.first, 0.5
    assert_in_delta 4.0, store_sleeps.last, 0.5
  end

  test "requests are spaced per process, across clients" do
    Steam::StoreApi.interval = 2.0
    stub_app_details(620 => app_details_entry(620))

    Steam::StoreApi.new.app_details(620)
    assert_empty store_sleeps
    Steam::StoreApi.new.app_details(620)

    assert_equal 1, store_sleeps.size
  end

  test "with no interval, requests are not spaced" do
    stub_app_details(620 => app_details_entry(620))

    3.times { Steam::StoreApi.new.app_details(620) }

    assert_empty store_sleeps
  end
end
