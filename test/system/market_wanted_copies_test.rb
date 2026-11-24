require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"

class MarketWantedCopiesSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @common = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    hold(@seller, @uncommon.id, 1)
    hold(@seller, @common.id, 1)
    buyer = accounts_players(:administrator)
    fund!(buyer, 10_000)
    order!(buyer, @uncommon, 900)
    Game::Market::RebuildWanted.new.call(player: buyer).value!
    Game::Market::Wanted.insert_all([ { player_id: accounts_players(:moderator).id, card_id: @uncommon.card_id, reason: "goal", rarities: nil } ])
    sign_in_browser(@seller.steam_id)
  end

  test "a wanted copy leads from the market's panel to its sale, its cell and its card detail carrying the count" do
    visit market_path(locale: :en)
    within(".wanted-panel") do
      assert_selector "h2", text: /YOUR WANTED CARDS\s+1/
      assert_selector ".wanted-panel__seekers", text: "2 players want it"
      assert_selector ".wanted-panel__order", text: /Order\s+900/
      find(".wanted-panel__tile", text: "Green Hills").click
    end

    assert_selector "[role=option][aria-selected=true]", text: "Green Hills"
    assert_selector "[role=option][aria-selected=true] .sale-cell__wanted", text: "SOUGHT · 2"
    assert_selector ".sale-order__title", text: /A buy order is waiting for you:\s+900/

    visit card_path(locale: :en, slug: @uncommon.card.slug)
    assert_selector ".card-detail__wanted .wanted-badge", text: "SOUGHT"
    assert_selector ".card-detail__wanted-line", text: /2 players want it · best order\s+900/
  end

  test "See all opens the sale grid on the wanted copies, and the chip lets the others back" do
    visit market_path(locale: :en)
    within(".wanted-panel__foot") { click_link "See all" }

    assert_selector "[role=option]", count: 1
    assert_selector "#sale-results-status", text: "1 card wanted by other players"

    find(".filter-chip", text: "WANTED BY OTHERS · 1").click

    assert_selector "[role=option]", count: 2
    assert_no_selector "#sale-results-status", text: /wanted by other players/

    find(".filter-chip", text: "WANTED BY OTHERS · 1").click
    assert_selector "[role=option]", count: 1
    click_on "Clear filters"

    assert_selector "[role=option]", count: 2
    assert_no_selector "input[name='filter[wanted]']:checked", visible: :all
  end
end
