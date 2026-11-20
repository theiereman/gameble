require "test_helper"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

# GET /:locale/exchanges: the trades tab and menu 03 open the sub-tab the player last used, the market the first
# time; a visitor reaches the market. The sub-tab bar sits on both sub-tabs' screens, for a player only.
class ExchangesControllerTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def subtabs = css_select("nav.exchanges-tabs[aria-label='Échanges'] a.exchanges-tabs__tab")

  test "the first time, the trades tab opens the market" do
    sign_in(@player)

    get exchanges_path(locale: :fr)

    assert_redirected_to market_path(locale: :fr)
    assert_response :found
  end

  test "once between friends is kept, the trades tab opens between friends" do
    Game::KeepExchangesTab.new.call(player: @player, tab: "friends").value!
    sign_in(@player)

    get exchanges_path(locale: :en)

    assert_redirected_to trades_path(locale: :en)
  end

  test "a visitor is sent to the market" do
    get exchanges_path(locale: :fr)

    assert_redirected_to market_path(locale: :fr)
  end

  test "between friends, the sub-tab bar names the market first, then between friends, the current one a page, each replacing the screen" do
    sign_in(@player)

    get trades_path(locale: :fr)

    assert_equal [ "/fr/market", "/fr/trades" ], subtabs.pluck("href")
    assert_equal [ "Marché", "Entre amis" ], css_select(".exchanges-tabs__label").map(&:text)
    assert_equal [ nil, "page" ], subtabs.pluck("aria-current")
    assert_equal [ "replace", "replace" ], subtabs.map { it["data-turbo-action"] }
    assert_select ".exchanges-tabs__tab svg.pixel-icon[aria-hidden=true]", 2
    assert_select "nav.exchanges-tabs[data-controller=exchanges-tabs][data-exchanges-tabs-current-value=friends]" \
      "[data-exchanges-tabs-kept-value=market][data-exchanges-tabs-url-value='/fr/exchanges/tab']"
    assert_select "#subtab-friends-badge.stream-slot", 1
    assert_select "#subtab-market-badge.stream-slot", 1
    assert_select ".exchanges-tabs__badge", 0
    assert_select "h1#trades-heading[tabindex='-1']"
    assert_select ".tab-bar a.tab-bar__tab[href='/fr/exchanges'][aria-current=page]", 1
  end

  test "the market screens carry the bar outside the market's frame, MARCHÉ current" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(@player)

    [ market_path(locale: :fr), market_my_bids_path(locale: :fr), market_my_sales_path(locale: :fr) ].each do |path|
      get path
      assert_response :success
      assert_equal [ "page", nil ], subtabs.pluck("aria-current"), path
      assert_select "turbo-frame#market-tab nav.exchanges-tabs", 0, path
      assert_select "nav.exchanges-tabs[data-exchanges-tabs-current-value=market][data-exchanges-tabs-kept-value=market]", 1, path
      assert_select ".tab-bar a.tab-bar__tab[href='/fr/exchanges'][aria-current=page]", 1, path
    end
    assert_select "h1#market-screen-heading[tabindex='-1']"
  end

  test "the market's teaser carries the bar too, for a player" do
    sign_in(@player)

    get market_path(locale: :en)

    assert_select "nav.exchanges-tabs[aria-label=Trades]", 1
    assert_select "h1.market-teaser__title[tabindex='-1']"
  end

  test "a visitor's market has no sub-tab bar and no tab bar" do
    get market_path(locale: :fr)
    assert_select "nav.exchanges-tabs", 0
    assert_select ".tab-bar", 0

    open_market!(first_opened_at: 1.day.ago)
    get market_path(locale: :fr)
    assert_select ".market-screen", 1
    assert_select "nav.exchanges-tabs", 0
    assert_select ".tab-bar", 0
  end

  test "a trade's board keeps the trades tab current, as a drill-down, and the bar hidden on the phone with the list" do
    sign_in(@player)

    get new_trade_path(locale: :en)

    assert_select ".tab-bar a.tab-bar__tab[href='/en/exchanges'][aria-current=true]", 1
    assert_select ".trades--board nav.exchanges-tabs", 1
  end
end
