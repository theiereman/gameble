require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"

# The Confier wanted table sells a Common or Uncommon to an order in one press; a Rare and above is auctioned, and an order backs the auction.
class MarketWantedTableRaritySystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @rare = catalog_card_seasons(:rare_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    fund!(@seller, 1_000)
    fund!(@buyer, 10_000)
    [ @rare, @uncommon ].each { hold(@seller, it.id, 1) }
    mock_steam_sign_in(@seller.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  def open_table(*cards) = visit new_market_wanted_choice_path(locale: :en, selection: cards.map { "#{ref(it)}=1" }.join(","))

  def line(card_season) = find(".wanted-line[data-ref='#{ref(card_season)}']")

  test "a Common or Uncommon line is sold to its order in one press" do
    order = order!(@buyer, @uncommon, 900)
    Game::Market::EditionPrice.create!(card_season_id: @uncommon.id, average: 950, sales_used: 5)
    open_table(@uncommon)

    within(line(@uncommon)) do
      assert_selector "input[value=order]:checked", visible: :all
      assert_selector "input[type=radio][name$='[choice]']", count: 3, visible: :all
    end
    click_on "VALIDATE MY CHOICE"

    assert_selector ".wanted-result__line--sold", text: "SOLD"
    assert_equal "served", order.reload.status
    assert_equal 1, Game::Holding.find_by!(player_id: @buyer.id, card_season_id: @uncommon.id).quantity
  end

  test "a Rare line has no order radio, opens its auction at the lowest order and the order leads it" do
    order = order!(@buyer, @rare, 700)
    open_table(@rare)

    within(line(@rare)) do
      assert_no_selector "input[value=order]", visible: :all
      assert_selector "input[type=radio][name$='[choice]']", count: 2, visible: :all
      assert_selector "input[value=auction]:checked", visible: :all
      assert_selector "[id$='-backed-note']", text: "A Rare or better is sold at auction, which buy orders back.", visible: :all
      assert_selector :field, name: /starting_price/, with: "700"
    end
    click_on "VALIDATE MY CHOICE"

    assert_selector ".wanted-result__line--listed", text: /\(led by a buy order at\s+700\s*\)/
    listing = Game::Market::Listing.find_by!(seller: @seller)
    assert_equal [ "bid", @buyer.id, 700 ], [ order.reload.status, listing.leader_id, listing.current_price ]
  end
end
