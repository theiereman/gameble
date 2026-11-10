require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

class MarketSalesSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    fund!(@seller, 50_000)
    fund!(@bidder, 100_000)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def reserved(card) = Game::Holding.find_by!(player_id: @seller.id, card_season_id: card.id).reserved

  test "a seller cancels from MES VENTES, gets the card back and focus lands on the next row" do
    hold(@seller, @common.id, 1, reserved: 1)
    hold(@seller, @rare.id, 1, reserved: 1)
    first = listing!(seller: @seller, card_season: @common, hours: 5)
    second = listing!(seller: @seller, card_season: @rare, hours: 9)
    sign_in_through_the_site(@seller)

    visit market_my_sales_path(locale: :en)
    assert_selector ".market-row", count: 2
    click_button "Cancel the sale, Tin Soldier"
    assert_selector "dialog#cancel-#{first.token}[open] h2:focus", text: "CANCEL THIS SALE?"
    within("dialog#cancel-#{first.token}") { click_button "CANCEL THE SALE" }

    assert_text "Sale cancelled."
    assert_equal "cancelled", first.reload.status
    assert_equal 0, reserved(@common)
    assert_selector ".market-row__chip", text: "CANCELLED"
    assert_equal "a", page.evaluate_script("document.activeElement.tagName").downcase
    assert_equal second.token, page.evaluate_script("document.activeElement.dataset.rowToken")
  end

  test "a seller relists an unsold copy with the amounts prefilled and lands on the new Annonce" do
    hold(@seller, @rare.id, 1)
    listing!(seller: @seller, card_season: @rare, status: "unsold", ends_at: 1.day.ago, starting_price: 9_000, buy_now_price: 20_000)
    sign_in_through_the_site(@seller)

    visit market_my_sales_path(locale: :en)
    click_link "Put up for sale again, Blue Depths"

    assert_selector ".market-sale__relisting", text: "These amounts are those of your previous sale."
    assert_field "starting_price", with: "9000"
    assert_field "buy_now_price", with: "20000"
    click_button "PUT UP FOR SALE"

    assert_selector "h1#market-listing-heading", text: "Blue Depths"
    assert_equal 2, Game::Market::Listing.where(seller_id: @seller.id, card_season_id: @rare.id).count
    assert_equal 1, reserved(@rare)
  end

  test "a late bid makes the cancel refuse with the Copy deck line" do
    hold(@seller, @common.id, 1, reserved: 1)
    listing = listing!(seller: @seller, card_season: @common, starting_price: 20_000)
    sign_in_through_the_site(@seller)

    visit market_my_sales_path(locale: :en)
    click_button "Cancel the sale, Tin Soldier"
    assert bid(@bidder, 30_000, listing).success?
    within("dialog#cancel-#{listing.token}") { click_button "CANCEL THE SALE" }

    assert_text "A bid just arrived. The sale can no longer be cancelled."
    assert_equal "open", listing.reload.status
    assert_equal 1, reserved(@common)
  end
end
