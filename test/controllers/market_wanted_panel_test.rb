require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

# On every market tab, the last chip counts how many of the player's copies other players want.
class MarketWantedPanelTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @player = accounts_players(:player)
  end

  def want_by_goal(card_season, *players)
    Game::Market::Wanted.insert_all(players.map { { player_id: it.id, card_id: card_season.card_id, reason: "goal", rarities: nil } })
  end

  def buyers_chip = css_select(".market-screen__chips .tabs__tab").last

  test "every tab ends on ACHETEURS, its badge counting the wanted copies, with no panel above the chips" do
    %i[rare_card_one common_card_one uncommon_card_one].each do |name|
      hold(@player, catalog_card_seasons(name).id)
      want_by_goal(catalog_card_seasons(name), accounts_players(:moderator))
    end
    sign_in(@player)

    [ market_path(locale: :fr), market_my_bids_path(locale: :fr), market_my_sales_path(locale: :fr), market_my_orders_path(locale: :fr) ].each do |path|
      get path

      assert_response :success
      assert_equal market_buyers_path(locale: :fr), buyers_chip["href"]
      assert_select buyers_chip, ".market-screen__badge[aria-hidden=true]", "3"
      assert_select buyers_chip, ".visually-hidden", "3 voulues"
      assert_match(/\AACHETEURS/, buyers_chip.text.strip)
      assert_select ".wanted-panel", false
    end
  end

  test "with no wanted copy the chip carries no badge" do
    hold(@player, catalog_card_seasons(:common_card_one).id)
    sign_in(@player)

    get market_path(locale: :fr)

    assert_equal "ACHETEURS", buyers_chip.text.strip
    assert_select ".market-screen__chips .market-screen__badge", false
  end

  test "a visitor sees the chip greyed, with no badge" do
    get market_path(locale: :en)

    assert_response :success
    assert_select ".market-screen__chips span.tabs__tab--disabled[aria-disabled=true]", "BUYERS"
    assert_select ".market-screen__chips .market-screen__badge", false
  end
end
