require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"
require_relative "../support/steam_sign_in"

# On every market tab, the last chip counts how many of the player's copies a buy order can take.
class MarketWantedPanelTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketAuctions
  include MarketOrders
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

  test "every tab ends on RECHERCHÉES, its badge counting the copies a buy order can take, not those only a goal wants" do
    %i[rare_card_one common_card_one uncommon_card_one].each do |name|
      hold(@player, catalog_card_seasons(name).id)
      want_by_goal(catalog_card_seasons(name), accounts_players(:moderator))
    end
    buyer = accounts_players(:administrator)
    fund!(buyer, 1_000)
    %i[rare_card_one common_card_one].each { order!(buyer, catalog_card_seasons(it), 100) }
    Game::Market::RebuildWanted.new.call(player: buyer).value!
    sign_in(@player)

    [ market_path(locale: :fr), market_my_bids_path(locale: :fr), market_my_sales_path(locale: :fr), market_my_orders_path(locale: :fr) ].each do |path|
      get path

      assert_response :success
      assert_equal market_buyers_path(locale: :fr), buyers_chip["href"]
      assert_select buyers_chip, ".market-screen__badge[aria-hidden=true]", "2"
      assert_select buyers_chip, ".visually-hidden", "2 avec un ordre d'achat"
      assert_match(/\ARECHERCHÉES/, buyers_chip.text.strip)
      assert_select ".wanted-panel", false
    end
  end

  test "the Archives' shop stays above the tabs on every market tab, so switching tabs does not shift the screen" do
    sign_in(@player)

    [ market_path(locale: :fr), market_my_bids_path(locale: :fr), market_my_sales_path(locale: :fr), market_my_orders_path(locale: :fr), market_buyers_path(locale: :fr) ].each do |path|
      get path

      assert_select ".shop-panel", 1
      assert_select ".market-screen [data-controller~=purchase-dialog]", 0
      assert_select ".market-screen[data-controller~=purchase-dialog]", 1
    end
  end

  test "with no wanted copy the chip carries no badge" do
    hold(@player, catalog_card_seasons(:common_card_one).id)
    sign_in(@player)

    get market_path(locale: :fr)

    assert_equal "RECHERCHÉES", buyers_chip.text.strip
    assert_select ".market-screen__chips .market-screen__badge", false
  end

  test "a visitor sees the chip greyed, with no badge" do
    get market_path(locale: :en)

    assert_response :success
    assert_select ".market-screen__chips span.tabs__tab--disabled[aria-disabled=true]", "SOUGHT"
    assert_select ".market-screen__chips .market-screen__badge", false
  end
end
