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
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 200, ends_at: 1.day.from_now)
    [ @first, @bidder ].each { fund!(it, 1_000) }
    bid(@first, 300)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def submit_button = find("#annonce-form button[type=submit]")

  test "the second bidder is beaten at once, takes the lead, then raises as the leader" do
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :en, token: @listing.token)

    assert_field "annonce-maximum", with: ""
    assert_selector "#annonce-minimum", text: /At least\s+210/
    fill_in "annonce-maximum", with: "250"
    assert_selector "#annonce-form button[type=submit]", text: "BID · 250"
    assert_selector "[role=status]", text: "250 PiCoins will be held", visible: :all
    find("#annonce-maximum").send_keys(:enter)
    assert_selector "#annonce-form button[type=submit]:focus"
    assert_equal 1, Game::Market::Bid.count

    submit_button.click

    assert_selector "#annonce-answer-heading", text: "ANOTHER PLAYER HAD A HIGHER MAXIMUM"
    assert_selector "#annonce-answer .picoin-amount__figure", text: "263"
    assert_selector "#annonce-answer .picoin-amount__figure", text: "277"
    assert_selector "#annonce-maximum:focus"
    assert_field "annonce-maximum", with: ""

    fill_in "annonce-maximum", with: "400"
    assert_selector "#annonce-form button[type=submit]", text: "BID · 400"
    submit_button.click

    assert_selector "#annonce-answer-heading:focus", text: "YOU ARE LEADING"
    assert_selector "#annonce-answer .picoin-amount__figure", text: "315"
    assert_selector "#annonce-minimum", text: /More than your current maximum,\s+400/
    assert_equal 400, Game::Market::Wallet.find_by!(player_id: @bidder.id).committed

    fill_in "annonce-maximum", with: "450"
    assert_selector "#annonce-form button[type=submit]", text: "RAISE · 450"
    submit_button.click

    assert_selector "#annonce-answer-heading", text: "MAXIMUM RAISED"
    assert_equal 450, Game::Market::Wallet.find_by!(player_id: @bidder.id).committed
    assert_equal 315, @listing.reload.current_price
  end

  test "a refusal stays under the field with the amount kept and clears on the next edit" do
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :en, token: @listing.token)

    fill_in "annonce-maximum", with: "150"
    submit_button.click

    assert_selector "#annonce-error", text: "At least 210 is needed."
    assert_selector "#annonce-maximum[aria-invalid=true]:focus"
    assert_field "annonce-maximum", with: "150"

    fill_in "annonce-maximum", with: "1500"
    assert_no_selector "#annonce-error", visible: :visible
    assert_no_selector "#annonce-maximum[aria-invalid]"
  end

  test "a French maximum groups its thousands with a no-break space as it is typed and is placed at that amount" do
    card = catalog_card_seasons(:uncommon_card_one)
    hold(@seller, card.id, 1, reserved: 1)
    listing = listing!(seller: @seller, card_season: card, starting_price: 400, ends_at: 1.day.from_now)
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :fr, token: listing.token)

    fill_in "annonce-maximum", with: "1000"
    assert_field "annonce-maximum", with: "1 000"
    submit_button.click

    assert_selector "#annonce-answer-heading"
    assert_equal 1_000, Game::Market::Wallet.find_by!(player_id: @bidder.id).committed
  end

  test "an unusual maximum asks confirmation, Escape returns to the field with the amount kept, then confirming places it" do
    sign_in_through_the_site(@bidder)
    visit market_listing_path(locale: :en, token: @listing.token)

    fill_in "annonce-maximum", with: "600"
    submit_button.click

    assert_selector "#annonce-unusual[open] h2:focus", text: "UNUSUAL AMOUNT"
    assert_selector "#annonce-unusual [data-annonce-dialog-target=amount]", text: "600", count: 2
    assert_selector "#annonce-unusual [data-annonce-dialog-target=multiple]", text: "3"

    page.send_keys(:escape)

    assert_no_selector "#annonce-unusual[open]"
    assert_selector "#annonce-maximum:focus"
    assert_field "annonce-maximum", with: "600"
    assert_equal 1, Game::Market::Bid.count

    submit_button.click
    within("#annonce-unusual") { click_on "CONFIRM 600" }

    assert_selector "#annonce-answer-heading", text: "YOU ARE LEADING"
    assert_equal 2, Game::Market::Bid.count
  end
end
