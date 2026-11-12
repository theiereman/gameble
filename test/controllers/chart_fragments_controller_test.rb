require "test_helper"
require_relative "../support/market"
require_relative "../support/market_snapshots"
require_relative "../support/steam_sign_in"

class ChartFragmentsControllerTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include MarketSnapshots
  include SteamSignIn

  setup do
    clear_snapshots
    Game::Market::ChartPublication.delete_all
    open_market!(first_opened_at: 40.days.ago)
    @yesterday = Time.current.utc.to_date - 1
    snapshot!(@yesterday - 1, created: 9_000, destroyed_total: 4_000, circulation: 395_000)
    snapshot!(@yesterday, created: 10_000, destroyed_total: 5_000, circulation: 400_000)
  end

  teardown { clear_snapshots }

  def publish(kind) = Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind:).value!

  def unpublish(kind) = Game::Market::UnpublishChart.new.call(player: accounts_players(:administrator), kind:).value!

  def reactor_path(version = @yesterday.iso8601, locale: :en) = chart_fragment_path(locale:, kind: "reactor", version:)

  def snapshot_prices!
    clear_snapshots
    snapshot!(@yesterday - 1, average_price_epic: 15_000, median_daily_earnings: 10_000)
    snapshot!(@yesterday, average_price_epic: 16_000, median_daily_earnings: 10_000)
  end

  def with_memory_cache
    cache_was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = cache_was
  end

  test "a published chart is a frame anyone may cache for a year, without a cookie, signed in or out" do
    publish("reactor")

    get reactor_path

    assert_response :success
    assert_equal "max-age=31536000, public, immutable", response.headers["Cache-Control"]
    assert_nil response.headers["Set-Cookie"]
    assert_select "turbo-frame#exchange-chart-reactor figure#reactor-flows"
    assert_select "turbo-frame#exchange-chart-reactor figure#reactor-circulation"
    assert_not_includes response.body, "<html"
    assert_select ".chart__staff-flag", false

    sign_in(accounts_players(:moderator))
    get reactor_path
    assert_nil response.headers["Set-Cookie"]
    assert_select ".chart__staff-flag", false
  end

  test "the fragment draws the window ending on its version's day, in the address's locale" do
    publish("reactor")

    get reactor_path(locale: :fr)

    assert_select "#reactor-flows-table tbody tr", 30
    assert_select "#reactor-flows-table tbody tr:first-child time[datetime=?]", @yesterday.iso8601
    assert_select "#reactor-flows summary", "VOIR LE TABLEAU"
  end

  test "the second request is answered from the cache under the same key" do
    publish("reactor")

    with_memory_cache do
      get reactor_path
      key = ChartFragmentsController.cache_key(:en, "reactor", @yesterday.iso8601)
      assert_equal response.body, Rails.cache.read(key)

      Rails.cache.write(key, "<turbo-frame id=\"exchange-chart-reactor\">from the cache</turbo-frame>")
      get reactor_path

      assert_equal "<turbo-frame id=\"exchange-chart-reactor\">from the cache</turbo-frame>", response.body
    end
  end

  test "the published rarity prices fragment holds the five tiles and the index chart" do
    publish("rarity_prices")
    snapshot_prices!

    get chart_fragment_path(locale: :en, kind: "rarity_prices", version: @yesterday.iso8601)

    assert_response :success
    assert_equal "max-age=31536000, public, immutable", response.headers["Cache-Control"]
    assert_select "turbo-frame#exchange-chart-rarity-prices .rarity-tiles > li", 5
    assert_select "turbo-frame#exchange-chart-rarity-prices figure#rarity-index"
    assert_select "#rarity-index-table tbody tr", 90
  end

  test "a version that is not the current one is not found" do
    publish("reactor")

    get reactor_path((@yesterday - 1).iso8601)
    assert_response :not_found

    get reactor_path("none")
    assert_response :not_found
  end

  test "before any snapshot the version reads none" do
    clear_snapshots
    publish("reactor")

    get reactor_path("none")

    assert_response :success
    assert_select "#reactor-flows"
  end

  test "an unpublished chart is not found, staff included" do
    get reactor_path
    assert_response :not_found

    publish("reactor")
    unpublish("reactor")
    sign_in(accounts_players(:administrator))
    get reactor_path
    assert_response :not_found
  end

  test "the exchange page embeds a published chart as a lazy frame whose address follows the last snapshot" do
    publish("reactor")

    get market_exchange_path(locale: :en)
    assert_select "turbo-frame#exchange-chart-reactor[loading=lazy][src=?]", reactor_path
    assert_select "#reactor-flows", false

    snapshot!(@yesterday + 1, created: 1, destroyed_total: 1, circulation: 400_000)
    get market_exchange_path(locale: :en)
    assert_select "turbo-frame#exchange-chart-reactor[src=?]", reactor_path((@yesterday + 1).iso8601)
  end

  test "staff see an unpublished chart inline, flagged, in a private page" do
    sign_in(accounts_players(:moderator))

    get market_exchange_path(locale: :en)

    assert_select "turbo-frame#exchange-chart-reactor", false
    assert_select "figure#reactor-flows .chart__staff-flag"
    assert_includes response.headers["Cache-Control"], "private"
  end
end
