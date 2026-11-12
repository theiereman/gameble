require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_snapshots"
require_relative "../support/steam_sign_in"

class MarketExchangeTest < ApplicationSystemTestCase
  include MarketSettings
  include MarketSnapshots
  include SteamSignIn

  CHART_CHUNK = /registration-[^\/]*\.js/

  setup do
    page.driver.browser.execute_cdp("Network.clearBrowserCache")
    clear_snapshots
    Game::Market::ChartPublication.delete_all
    open_market!(first_opened_at: 40.days.ago)
    @yesterday = Time.current.utc.to_date - 1
    30.times do |ago|
      snapshot!(@yesterday - ago, created: 10_000 + ago, destroyed_total: 5_600, circulation: 412_600_000 - (ago * 4_400))
    end
  end

  teardown { clear_snapshots }

  def sign_in_as(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def loaded_scripts = evaluate_script("performance.getEntriesByType('resource').map((entry) => entry.name)")

  test "staff read the Reactor's figures and charts, and its table matches the snapshots" do
    sign_in_as(accounts_players(:moderator))
    visit market_path(locale: :en)
    assert_selector "h1", text: "Market"
    assert_no_match CHART_CHUNK, loaded_scripts.join(" ")

    visit market_exchange_path(locale: :en)

    assert_selector "h1", text: "The Brotherhood's Exchange"
    within("[data-exchange-panel=reactor]") do
      assert_selector ".chart-figures__item", count: 4
      assert_selector ".chart-figures__item", text: /\AIN CIRCULATION\s+412\.6M/
      assert_selector ".chart-figures__item", text: /\ADESTROYED \/ MINTED\s+55\.9%\z/
      assert_selector "h3", text: "MINTED AND DESTROYED PER DAY"
      assert_selector "h3", text: "PICOINS IN CIRCULATION"
      assert_selector "#reactor-flows canvas[style*=height]"
      assert_selector "#reactor-circulation canvas[style*=height]"

      within("#reactor-flows") { find("summary", text: "SHOW THE TABLE").click }
      within("#reactor-flows table") do
        assert_selector "tbody tr", count: 30
        within("tbody tr:first-child") { assert_text(/10,000\s+5,600\s+\+4,400/) }
        within("tbody tr:last-child") { assert_text(/10,029\s+5,600\s+\+4,429/) }
      end
    end
    assert_match CHART_CHUNK, loaded_scripts.join(" ")
  end

  test "with the rarity prices published a visitor reads five tiles and the index, its table a row per day and a column per rarity" do
    clear_snapshots
    90.times do |ago|
      snapshot!(@yesterday - ago, average_price_epic: 16_000 - (ago * 50), average_price_common: 2_500, median_daily_earnings: 10_000)
    end
    Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind: "rarity_prices").value!

    visit market_exchange_path(locale: :en)

    assert_no_selector "[data-exchange-panel=reactor]"
    within("[data-exchange-panel=rarity_prices]") do
      assert_selector "h2", text: "WHAT A CARD COSTS"
      assert_selector ".rarity-tiles > li", count: 5
      assert_selector ".rarity-tile--epic", text: /\AEpic\s+1\.6 d\s+1\.6 days\s+\+38\.5%\s+plus 38\.5%\s+in 90 d\z/
      assert_selector ".rarity-tile--epic .chart--spark canvas[style*=height]"
      assert_no_selector ".rarity-tile--rare .chart--spark"
      assert_selector "#rarity-index canvas[style*=height]"
      assert_selector "#rarity-index .chart__legend-item", text: "Epic · 138.5"
      assert_no_text "VISIBLE TO STAFF"

      within("#rarity-index") { find("summary", text: "SHOW THE TABLE").click }
      within("#rarity-index table") do
        assert_selector "caption", text: /base 100/
        assert_selector "thead th", count: 6
        assert_selector "tbody tr", count: 90
      end
    end
  end

  test "at 320 CSS px the index keeps its HTML legend without end labels, and the Reactor's table scrolls in its region alone" do
    90.times do |ago|
      snapshot!(@yesterday - 30 - ago, average_price_epic: 16_000, median_daily_earnings: 10_000)
    end
    %w[reactor rarity_prices].each { Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind: it).value! }
    resize_to(320, 800)

    visit market_exchange_path(locale: :en)
    assert_selector "#reactor-circulation[data-chart-layout=narrow]"
    figures = "[...document.querySelectorAll('.chart-figures__value')].every((figure) => figure.scrollWidth <= figure.clientWidth)"
    assert evaluate_script(figures), "each headline figure fits its cell"
    page.execute_script("document.getElementById('exchange-chart-rarity-prices').scrollIntoView({ block: 'center' })")

    assert_selector "#rarity-index[data-chart-layout=narrow] canvas[style*=height]"
    assert_selector "#rarity-index .chart__legend-item", count: 5
    assert_selector "#reactor-flows[data-chart-layout=narrow]"
    within("#reactor-flows") do
      find("summary", text: "SHOW THE TABLE").click
      assert_selector "summary", text: "HIDE THE TABLE"
      assert_selector ".chart__scroll[role=region][tabindex='0']"
    end
    region_scrolls = "(() => { const region = document.querySelector('#reactor-flows .chart__scroll'); return region.scrollWidth > region.clientWidth })()"
    eventually("the Reactor's table scrolls inside its region") { evaluate_script(region_scrolls) }
    assert_equal false, evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "a visitor and a player find no exchange" do
    visit market_exchange_path(locale: :en)
    assert_no_selector ".exchange"

    sign_in_as(accounts_players(:player))
    visit market_exchange_path(locale: :en)
    assert_no_selector ".exchange"
    assert_no_selector ".chart"
  end
end
