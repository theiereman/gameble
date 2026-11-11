require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

# Before the first opening the market address shows the teaser; after it a visitor reads the listings and opens an Annonce.
class MarketTest < ApplicationSystemTestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    Game::Market::Settings.delete_all
    @seller = accounts_players(:player)
    @seller.update_columns(persona_name: "Alice")
  end

  test "the teaser shows until the first opening, then a visitor reads the listings, sorts them and opens an Annonce" do
    open_market!(open: false)
    visit market_path(locale: :en)
    assert_selector "h1", text: "The Brotherhood is building the market"

    open_market!(first_opened_at: 1.day.ago)
    cheap = listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one), starting_price: 1_300, hours: 12)
    listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one), starting_price: 9_000, hours: 72)

    visit market_path(locale: :en)
    assert_selector "h1", text: "Market"
    assert_selector ".listing-tile", count: 2
    assert_equal "Tin Soldier", first(".listing-tile a")["aria-label"].split(",").first

    click_on "Price, high to low"
    assert_selector ".market-screen__sort[aria-current=true]", text: "Price, high to low"
    assert_equal "Blue Depths", first(".listing-tile a")["aria-label"].split(",").first

    find(".listing-tile a[href$='#{cheap.token}']").click
    assert_selector "h1#market-listing-heading", text: "Tin Soldier"
    assert_equal "market-listing-heading", page.evaluate_script("document.activeElement.id")
    assert_selector ".market-listing__price", text: "1,300"
    assert_selector ".market-listing__ends time"
    assert_selector ".market-listing__fact a", text: "Alice"
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "an administrator suspends the market: the banner shows, actions are disabled, a seller still cancels and a due auction still settles" do
    opened = 2.days.ago.change(usec: 0)
    open_market!(first_opened_at: opened, terms_confirmed_at: opened, odds_confirmed_at: opened)
    bidder = accounts_players(:moderator)
    common = catalog_card_seasons(:common_card_one)
    rare = catalog_card_seasons(:rare_card_one)
    uncommon = catalog_card_seasons(:uncommon_card_one)
    [ common, rare, uncommon ].each { hold(@seller, it.id, 1, reserved: 1) }
    cancellable = listing!(seller: @seller, card_season: common, starting_price: 20_000)
    biddable = listing!(seller: @seller, card_season: uncommon, starting_price: 20_000)
    due = listing!(seller: @seller, card_season: rare, starting_price: 20_000)
    fund!(bidder, 100_000)
    assert bid(bidder, 30_000, due).success?
    due.update_columns(ends_at: 1.minute.ago)

    sign_in_through_the_site(accounts_players(:administrator))
    visit back_office_market_path(locale: :en)
    within("#market-closing") do
      fill_in "Message in French", with: "Le marché est suspendu"
      fill_in "Message in English", with: "The market is suspended"
      click_on "Close the market"
    end
    assert_text "The market is closed and the announcement is on the banner."

    using_session(:seller) do
      sign_in_through_the_site(@seller)
      visit market_path(locale: :en)
      assert_selector "#market-suspended-banner", text: "THE MARKET IS SUSPENDED"
      assert_button "PUT UP FOR SALE", disabled: true
      assert_selector ".listing-tile", minimum: 1

      visit market_my_sales_path(locale: :en)
      assert_selector "#market-suspended-banner"
      find("button[aria-label='Cancel the sale, Tin Soldier']").click
      within("dialog#cancel-#{cancellable.token}") { click_button "CANCEL THE SALE" }
      assert_text "Sale cancelled."
      assert_equal "cancelled", cancellable.reload.status
      assert_equal 0, Game::Holding.find_by!(player_id: @seller.id, card_season_id: common.id).reserved
    end

    using_session(:bidder) do
      sign_in_through_the_site(bidder)
      visit market_listing_path(locale: :en, token: biddable.token)
      assert_selector "#annonce-suspension #market-suspended-banner"
      assert_field "annonce-maximum", disabled: true
      assert_button "BID", disabled: true
      assert_selector ".market-listing__price", text: "20,000"
    end

    assert Game::Market::CloseAuction.new.call(player: @seller, listing_id: due.id).success?
    assert_equal "sold", due.reload.status
  end
end
