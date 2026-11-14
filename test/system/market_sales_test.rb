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

  test "the market tabs swap in place: no visit, the desk stays, the address and title follow" do
    listing!(seller: @seller, card_season: @common, hours: 5)
    sign_in_through_the_site(@seller)
    visit market_path(locale: :en)
    assert_selector ".listing-tile", count: 1
    page.execute_script("window.marketVisits = 0; addEventListener('turbo:visit', () => window.marketVisits++)")

    within(".market-screen__chips") { click_on "MY SALES" }
    assert_selector ".market-screen__chip--current", text: "MY SALES"
    assert_selector ".market-row", count: 1
    assert_current_path market_my_sales_path(locale: :en)
    assert_title "My sales"
    assert_selector ".market-desk h1", text: "Market"
    assert_no_selector ".top-bar__phone-back"

    within(".market-screen__chips") { click_on "MY BIDS" }
    assert_selector ".market-screen__chip--current", text: "MY BIDS"
    assert_current_path market_my_bids_path(locale: :en)

    within(".market-screen__chips") { click_on "LISTINGS" }
    assert_selector ".listing-tile", count: 1
    assert_current_path market_path(locale: :en)
    assert_title "Market"
    assert_equal 0, page.evaluate_script("window.marketVisits")
  end

  test "a seller cancels from MES VENTES, gets the card back and focus lands on the next row" do
    hold(@seller, @common.id, 1, reserved: 1)
    hold(@seller, @rare.id, 1, reserved: 1)
    first = listing!(seller: @seller, card_season: @common, hours: 5)
    second = listing!(seller: @seller, card_season: @rare, hours: 9)
    sign_in_through_the_site(@seller)

    visit market_my_sales_path(locale: :en)
    assert_selector ".market-row", count: 2
    find("button[aria-label='Cancel the sale, Tin Soldier']").click
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
    listing!(seller: @seller, card_season: @rare, status: "unsold", ends_at: 1.day.ago, starting_price: 9_000)
    sign_in_through_the_site(@seller)

    visit market_my_sales_path(locale: :en)
    find("a[aria-label='Put up for sale again, Blue Depths']").click

    assert_selector ".market-sale__relisting", text: "These amounts are those of your previous sale."
    assert_field "starting_price", with: "9,000"
    click_button "PUT UP FOR SALE"

    assert_selector "h1#market-listing-heading", text: "Blue Depths"
    assert_equal 2, Game::Market::Listing.where(seller_id: @seller.id, card_season_id: @rare.id).count
    assert_equal 1, reserved(@rare)
  end

  test "the starting price groups its thousands as it is typed, the caret staying where the player edits" do
    hold(@seller, @rare.id, 1)
    sign_in_through_the_site(@seller)

    visit new_market_card_sale_path(locale: :en, slug: @rare.card.slug)
    field = find_field("starting_price")
    field.send_keys("12345678")
    assert_field "starting_price", with: "12,345,678"

    field.send_keys(:home, :right, :right, :right, :backspace, "9")
    assert_field "starting_price", with: "19,345,678"

    click_button "PUT UP FOR SALE"
    assert_selector "h1#market-listing-heading", text: "Blue Depths"
    assert_equal 19_345_678, Game::Market::Listing.where(seller_id: @seller.id).last.starting_price
  end

  test "a late bid makes the cancel refuse with the Copy deck line" do
    hold(@seller, @common.id, 1, reserved: 1)
    listing = listing!(seller: @seller, card_season: @common, starting_price: 20_000)
    sign_in_through_the_site(@seller)

    visit market_my_sales_path(locale: :en)
    find("button[aria-label='Cancel the sale, Tin Soldier']").click
    assert bid(@bidder, 30_000, listing).success?
    within("dialog#cancel-#{listing.token}") { click_button "CANCEL THE SALE" }

    assert_text "A bid just arrived. The sale can no longer be cancelled."
    assert_equal "open", listing.reload.status
    assert_equal 1, reserved(@common)
  end
end
