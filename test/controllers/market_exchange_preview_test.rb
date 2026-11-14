require "test_helper"
require_relative "../support/market"
require_relative "../support/market_snapshots"
require_relative "../support/steam_sign_in"

class MarketExchangePreviewTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include MarketSnapshots
  include SteamSignIn

  setup do
    clear_snapshots
    Game::Market::ChartPublication.delete_all
    open_market!(first_opened_at: 40.days.ago)
    @yesterday = Time.current.utc.to_date - 1
  end

  teardown { clear_snapshots }

  def publish(kind) = Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind:).value!

  def priced_month
    30.times do |ago|
      snapshot!(@yesterday - ago, created: 10_000, destroyed_total: 5_600, circulation: 412_600_000, median_daily_earnings: 1_000,
        average_price_common: 500, average_price_epic: ago.zero? ? 11_000 : 10_000)
    end
  end

  def preview = css_select("a.exchange-preview").first

  test "every market tab shows the exchange's prices and figures as one link to the exchange" do
    priced_month
    publish("reactor")
    publish("rarity_prices")
    sign_in(accounts_players(:player))

    [ market_path(locale: :en), market_my_bids_path(locale: :en), market_my_sales_path(locale: :en) ].each do |path|
      get path

      assert_select "a.exchange-preview[href=?]", market_exchange_path(locale: :en)
    end
    assert_select ".market-screen__chips a[href=?]", market_exchange_path(locale: :en), false
    assert_select "a.exchange-preview .exchange-preview__title", "THE BROTHERHOOD'S EXCHANGE"
    assert_select ".exchange-preview__rarity", 5
    assert_select ".exchange-preview__rarity--epic .exchange-preview__price", text: /11 d/
    assert_select ".exchange-preview__rarity--epic .exchange-preview__change--up", text: /\+10%/
    assert_select ".exchange-preview__rarity--epic .chart--spark[aria-hidden=true]"
    assert_select ".exchange-preview__rarity--rare .exchange-preview__change--flat"
    assert_select ".exchange-preview__value", text: /412.6M/
    assert_select ".exchange-preview__value", text: /56%/
    assert_select "a.exchange-preview a, a.exchange-preview button, a.exchange-preview details", false
    assert_select "[style]", false
  end

  test "before any price the preview says when the first prices come, and keeps the reactor" do
    30.times { |ago| snapshot!(@yesterday - ago, created: 10_000, destroyed_total: 5_600, circulation: 412_600_000) }
    publish("reactor")
    publish("rarity_prices")

    get market_path(locale: :fr)

    assert_select ".exchange-preview__rarity", false
    assert_select ".exchange-preview__empty", "Les premiers cours paraissent au lendemain des premières ventes."
    assert_select ".exchange-preview__label", "EN CIRCULATION"
  end

  test "only the published charts appear, and nothing while none is" do
    priced_month

    get market_path(locale: :en)
    assert_nil preview

    publish("reactor")
    get market_path(locale: :en)
    assert_select ".exchange-preview__reactor"
    assert_select ".exchange-preview__rarities", false
    assert_select ".exchange-preview__window", false
  end

  test "staff see the unpublished charts in the preview, as on the exchange" do
    priced_month
    sign_in(accounts_players(:moderator))

    get market_path(locale: :en)

    assert_select ".exchange-preview__rarity", 5
    assert_select ".exchange-preview__reactor"
  end
end
