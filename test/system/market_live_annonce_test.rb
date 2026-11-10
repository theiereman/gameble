require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

# An Annonce kept open follows the auction: another player's bid reaches its price, leader and history without a reload,
# while the amount being typed and an open dialog stay as they are.
class MarketLiveAnnonceSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @reader = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @rival.update!(persona_name: "Rival")
    @card = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @reader, @rival ].each { fund!(it, 200_000) }
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def open_annonce
    visit market_listing_path(locale: :en, token: @listing.token)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
  end

  def rival_bids(maximum)
    bid(@rival, maximum)
    perform_enqueued_jobs(only: ListingStreamJob)
  end

  test "another player's bid reaches the open Annonce while the reader keeps typing with focus" do
    sign_in_through_the_site(@reader)
    open_annonce
    find_field("annonce-maximum").click
    fill_in "annonce-maximum", with: "26000"

    rival_bids(30_000)

    assert_selector ".market-listing__leader", text: "Rival"
    assert_selector ".market-history__line--bid", count: 1
    assert_field "annonce-maximum", with: "26000"
    assert_equal "annonce-maximum", page.evaluate_script("document.activeElement.id")
    assert_selector "#annonce-bid button[type=submit]", text: /BID · 26,000/
  end

  test "an open unusual-maximum dialog stays open through a refresh" do
    sign_in_through_the_site(@reader)
    open_annonce
    fill_in "annonce-maximum", with: "100000"
    find("#annonce-form button[type=submit]", match: :first).click
    assert_selector "dialog[open]"

    rival_bids(30_000)

    assert_selector "dialog#annonce-unusual[open]"
    assert_no_selector ".market-listing__leader"

    find("#annonce-unusual .modal__close").click
    assert_selector ".market-listing__leader", text: "Rival"
  end

  test "a bid in the last three minutes shows the extended panel and the new end to a visitor" do
    @listing.update_columns(ends_at: 2.minutes.from_now)
    visit market_listing_path(locale: :en, token: @listing.token)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    rival_bids(30_000)

    assert_selector "#annonce-extended h2", text: "AUCTION EXTENDED"
    assert_selector "#annonce-extended time[datetime]"
  end

  test "an auction that ends while the reader has typed gives the outcome's heading focus, with nothing submitted" do
    sign_in_through_the_site(@reader)
    @listing.update_columns(ends_at: 7.seconds.from_now)
    open_annonce
    find_field("annonce-maximum").click
    fill_in "annonce-maximum", with: "26000"
    bids = Game::Market::Bid.count

    sleep 7.5
    Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)
    perform_enqueued_jobs(only: ListingStreamJob)

    assert_selector "#listing-outcome-heading", text: "AUCTION ENDED"
    assert_equal "listing-outcome-heading", page.evaluate_script("document.activeElement.id")
    assert_selector "#annonce-bid .market-bid__note", text: "Your amount was not recorded."
    assert_no_field "annonce-maximum"
    assert_equal bids, Game::Market::Bid.count
    assert_selector "[role=status]", text: "AUCTION ENDED", visible: :all
  end
end
