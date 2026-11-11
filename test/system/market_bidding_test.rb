require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

class MarketBiddingSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @first = accounts_players(:moderator)
    @bidder = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @first, @bidder ].each { fund!(it, 100_000) }
    bid(@first, 30_000)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def submit_button = find("#annonce-form button[type=submit]")

  test "a visitor reads the sign-in line instead of the form" do
    visit market_listing_path(locale: :en, token: @listing.token)

    assert_link "Sign in to bid"
    assert_no_field "annonce-maximum"
  end

  test "the second bidder is beaten at once, takes the lead, then raises as the leader" do
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :en, token: @listing.token)

    assert_field "annonce-maximum", with: ""
    assert_selector "#annonce-minimum", text: /At least\s+21,000/
    fill_in "annonce-maximum", with: "25000"
    assert_selector "#annonce-form button[type=submit]", text: "BID · 25,000"
    assert_selector "[role=status]", text: "25,000 PiCoins will be held", visible: :all
    find("#annonce-maximum").send_keys(:enter)
    assert_selector "#annonce-form button[type=submit]:focus"
    assert_equal 1, Game::Market::Bid.count

    submit_button.click

    assert_selector "#annonce-answer-heading", text: "ANOTHER PLAYER HAD A HIGHER MAXIMUM"
    assert_selector "#annonce-answer .picoin-amount__figure", text: "26,300"
    assert_selector "#annonce-answer .picoin-amount__figure", text: "27,700"
    assert_selector "#annonce-maximum:focus"
    assert_field "annonce-maximum", with: ""

    fill_in "annonce-maximum", with: "40000"
    assert_selector "#annonce-form button[type=submit]", text: "BID · 40,000"
    submit_button.click

    assert_selector "#annonce-answer-heading:focus", text: "YOU ARE LEADING"
    assert_selector "#annonce-answer .picoin-amount__figure", text: "31,500"
    assert_selector "#annonce-minimum", text: /More than your current maximum,\s+40,000/
    assert_equal 40_000, Game::Market::Wallet.find_by!(player_id: @bidder.id).committed

    fill_in "annonce-maximum", with: "45000"
    assert_selector "#annonce-form button[type=submit]", text: "RAISE · 45,000"
    submit_button.click

    assert_selector "#annonce-answer-heading", text: "MAXIMUM RAISED"
    assert_equal 45_000, Game::Market::Wallet.find_by!(player_id: @bidder.id).committed
    assert_equal 31_500, @listing.reload.current_price
  end

  test "a refusal stays under the field with the amount kept and clears on the next edit" do
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :en, token: @listing.token)

    fill_in "annonce-maximum", with: "15000"
    submit_button.click

    assert_selector "#annonce-error", text: "At least 21,000 is needed."
    assert_selector "#annonce-maximum[aria-invalid=true]:focus"
    assert_field "annonce-maximum", with: "15000"

    fill_in "annonce-maximum", with: "150000"
    assert_no_selector "#annonce-error", visible: :visible
    assert_no_selector "#annonce-maximum[aria-invalid]"
  end

  test "an unusual maximum asks confirmation, Escape returns to the field with the amount kept, then confirming places it" do
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :en, token: @listing.token)

    fill_in "annonce-maximum", with: "60000"
    submit_button.click

    assert_selector "#annonce-unusual[open] h2:focus", text: "UNUSUAL AMOUNT"
    assert_selector "#annonce-unusual [data-annonce-dialog-target=amount]", text: "60,000", count: 2
    assert_selector "#annonce-unusual [data-annonce-dialog-target=multiple]", text: "3"

    page.send_keys(:escape)

    assert_no_selector "#annonce-unusual[open]"
    assert_selector "#annonce-maximum:focus"
    assert_field "annonce-maximum", with: "60000"
    assert_equal 1, Game::Market::Bid.count

    submit_button.click
    within("#annonce-unusual") { click_on "CONFIRM 60,000" }

    assert_selector "#annonce-answer-heading", text: "YOU ARE LEADING"
    assert_equal 2, Game::Market::Bid.count
  end

  test "a buyer cancels the buy-now confirmation back to its button, then confirms and reads the purchase" do
    @listing.update_columns(buy_now_price: 80_000)
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :en, token: @listing.token)

    find("button[name=buy_now]").click
    assert_selector "#annonce-buy-now[open] h2:focus", text: "BUY NOW"
    assert_selector "#annonce-buy-now", text: "Tin Soldier, common"
    within("#annonce-buy-now") { click_on "CANCEL" }

    assert_no_selector "#annonce-buy-now[open]"
    assert_selector "button[name=buy_now]:focus"
    assert_equal 1, Game::Market::Bid.count

    find("button[name=buy_now]").click
    within("#annonce-buy-now") { click_on "BUY · 80,000" }

    assert_selector "#listing-outcome-heading", text: "YOU BOUGHT TIN SOLDIER"
    assert_link "SEE THE CARD"
    assert_equal 1, Game::Holding.where(player_id: @bidder.id, card_season_id: @card.id).sum(:quantity)
  end
end
