require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"

class MarketDirectSaleSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @common = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    fund!(@seller, 1_000)
    fund!(@buyer, 10_000)
    hold(@seller, @uncommon.id, 1)
    hold(@seller, @common.id, 1)
    @order = order!(@buyer, @uncommon, 900)
    sign_in_browser(@seller.steam_id)
    visit new_market_sale_path(locale: :en)
  end

  def choose(title) = find("[role=option]", text: title).click

  test "a holder sells to the waiting order in one press and reads the sold panel" do
    choose("Tin Soldier")
    assert_selector ".sale-order-none", text: "No buy order for this card."
    assert_selector ".sale-summary button.button--primary", text: /PUT UP FOR SALE/

    choose("Green Hills")
    assert_selector ".sale-order__title", text: /A buy order is waiting for you:\s+900/
    assert_selector ".sale-order__terms", text: /You receive\s+810/
    assert_selector ".sale-summary button.button--secondary", text: /PUT UP FOR SALE/
    find("button[aria-label='Sell now to the buy order, 810 PiCoins received']", text: "SELL NOW").click

    assert_selector ".market-outcome h2:focus", text: "SOLD"
    assert_selector ".market-outcome__body", text: /Green Hills is sold to a buy order\. You receive\s+810/
    assert_equal "served", @order.reload.status
    assert_equal 1, Game::Holding.find_by!(player_id: @buyer.id, card_season_id: @uncommon.id).quantity
  end

  test "a better order placed after the screen was drawn is refused inline, focus on its sentence" do
    choose("Green Hills")
    assert_selector ".sale-order__title", text: /900/
    fund!(accounts_players(:administrator), 10_000)
    better = order!(accounts_players(:administrator), @uncommon, 1_000)

    find("button[aria-label='Sell now to the buy order, 810 PiCoins received']", text: "SELL NOW").click

    assert_selector ".sale-order__refusal:focus", text: "A better order just arrived: 1,000 PiCoins. Check it, then validate again."
    assert_selector ".sale-order button[name=order][value='#{better.token}']"
    assert_equal [ "open", "open" ], [ @order.reload.status, better.reload.status ]
  end
end
