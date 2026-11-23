require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"

class MarketConfierWantedSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @camille = accounts_players(:player)
    @buyer = accounts_players(:administrator)
    @seeker = accounts_players(:moderator)
    @rare = catalog_card_seasons(:rare_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @epic = catalog_card_seasons(:portal_one)
    @common = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    [ @rare, @uncommon, @epic ].each { hold(@camille, it.id) }
    hold(@camille, @common.id, 2)
    fund!(@buyer, 10_000)
    @order = order!(@buyer, @rare, 900)
    Game::Market::RebuildWanted.new.call(player: @buyer).value!
    Game::Market::Wanted.insert_all([ @uncommon, @epic ].map { { player_id: @seeker.id, card_id: it.card_id, reason: "goal", rarities: nil } })
    Game::Market::EditionPrice.create!(card_season_id: @rare.id, average: 950, sales_used: 5)
    mock_steam_sign_in(@camille.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def cell(card_season) = find(".entrust-cell[data-ref='#{card_season.card.slug}:#{card_season.season.number}']")

  def tick(card_season) = cell(card_season).find(".entrust-cell__toggle").click

  def line(card_season) = find(".wanted-line[data-ref='#{card_season.card.slug}:#{card_season.season.number}']")

  def open_entrust
    visit new_market_entrustment_path(locale: :en)
    find(".copy-filters .filter-chip__text", text: "2+").click
    assert_selector ".entrust-cell", count: 4
  end

  test "Camille entrusts her spare copies at once, then sells, lists and entrusts the wanted ones in one validation" do
    open_entrust
    [ @rare, @uncommon, @epic, @common ].each { tick(it) }
    cell(@common).find(".stepper__button--more").click

    assert_selector ".entrust-grid__step", text: "Step 1 of 2"
    assert_selector ".entrust-recap__set-apart-heading", text: "SET ASIDE · 3 WANTED CARDS"
    assert_selector ".entrust-recap__set-apart-line", count: 3
    click_on "Entrust 2 copies"

    assert_selector ".wanted-strip__step", text: "Step 2 of 2"
    assert_selector ".wanted-strip__first", text: "The 2 other copies are already entrusted: 20 PiCoins minted."
    assert_selector "#market-wanted-heading:focus"
    within(line(@rare)) { assert_selector "input[value=order]:checked", visible: :all }
    within(line(@epic)) { assert_selector "input[value=entrust]:checked", visible: :all }
    within(line(@uncommon)) { assert_selector "input[value=entrust]:checked", visible: :all }

    within(line(@epic)) do
      find("label", text: "AUCTION").click
      find("input[name$='[starting_price]']").set("5000")
    end
    click_on "VALIDATE THE 3 CHOICES"

    assert_selector "#wanted-result-heading:focus", text: "YOUR 3 CHOICES ARE APPLIED"
    assert_selector ".wanted-result__line--sold", text: "SOLD"
    assert_selector ".wanted-result__line--listed", text: "RUNNING"
    assert_selector ".wanted-result__line--listed a", text: "SEE THE LISTING ▸"
    assert_selector ".wanted-result__line--entrusted", text: "ENTRUSTED"
    assert_equal [ 1, 1 ], [ Game::Holding.find_by(player_id: @buyer.id, card_season_id: @rare.id).quantity, Game::Market::Listing.where(seller: @camille, status: "open").count ]
    assert_equal 1, Game::Market::ArchiveDeposit.find_by(player_id: @camille.id, card_season_id: @uncommon.id).quantity
  end

  test "an order served before the press redraws its line with its new choice and nothing moves" do
    open_entrust
    tick(@rare)
    click_on "CHOOSE FOR THE WANTED CARD ▸"

    assert_selector ".wanted-strip__step", text: "Step 2 of 2"
    within(line(@rare)) { assert_selector "input[value=order]:checked", visible: :all }
    @order.update_columns(status: "withdrawn")
    click_on "VALIDATE MY CHOICE"

    assert_selector "#wanted-dock-refusal", text: "1 line changed: Blue Depths. Nothing was sold, listed or entrusted."
    within(line(@rare)) do
      assert_selector ".wanted-line__none", text: "No order"
      assert_selector ".wanted-line__changed", text: /This buy order has just been served, and no other reaches this card\..*Your choice is now ENTRUST\./
      assert_selector "input[value=entrust]:checked:focus", visible: :all
    end
    assert_equal 1, Game::Holding.find_by(player_id: @camille.id, card_season_id: @rare.id).quantity
    assert_nil Game::Holding.find_by(player_id: @buyer.id, card_season_id: @rare.id)
  end
end
