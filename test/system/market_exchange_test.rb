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
    clear_snapshots
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

  test "a visitor and a player find no exchange" do
    visit market_exchange_path(locale: :en)
    assert_text "RecordNotFound"

    sign_in_as(accounts_players(:player))
    visit market_exchange_path(locale: :en)
    assert_text "RecordNotFound"
    assert_no_selector ".chart"
  end
end
