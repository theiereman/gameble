require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

class MarketAnnonceSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @loser = accounts_players(:moderator)
    @winner = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @loser, @winner ].each { fund!(it, 100_000) }
    bid(@loser, 30_000)
    bid(@winner, 25_000)
    @listing.update_columns(ends_at: 1.minute.from_now)
    bid(@winner, 40_000)
    bid(@winner, 45_000)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def close_auction
    @listing.update_columns(ends_at: 1.minute.ago)
    Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)
  end

  def annonce = visit(market_listing_path(locale: :en, token: @listing.token))

  test "a visitor reads the history newest first with the extension line and no raise line" do
    annonce

    assert_selector ".market-history__line--bid", count: 2
    assert_selector ".market-history__line--covered", count: 1, text: "keeps the lead over"
    assert_selector ".market-history__line--extension", text: "Auction extended until"
    assert_selector ".market-history__line--raise", count: 0
    assert_selector ".market-history__leading", count: 1, text: "LEADING"
    assert_selector ".market-history__line--created", text: "Listed by"
    assert_selector ".market-listing__leader", text: "Leading:"
  end

  test "an open listing past its end reads closing" do
    @listing.update_columns(ends_at: 1.minute.ago)
    annonce

    assert_selector "#annonce-bid", text: "Closing…"
  end

  test "the winner, a loser, the seller and a visitor each read their outcome" do
    close_auction

    using_session(:winner) do
      sign_in_through_the_site(@winner)
      annonce
      assert_selector "#listing-outcome-heading", text: "YOU WON TIN SOLDIER"
      assert_link "SEE THE CARD"
      assert_selector ".market-history__line--raise", count: 1
    end
    using_session(:loser) do
      sign_in_through_the_site(@loser)
      annonce
      assert_selector "#listing-outcome-heading", text: "AUCTION ENDED"
      assert_text "Your PiCoins were returned."
    end
    using_session(:seller) do
      sign_in_through_the_site(@seller)
      annonce
      assert_selector "#listing-outcome-heading", text: "SOLD"
      assert_text "You receive"
    end
    annonce
    assert_selector "#listing-outcome-heading", text: "AUCTION ENDED"
    assert_no_text "Your PiCoins were returned."
    assert_selector ".market-history__line--bid", count: 3
    assert_selector ".market-history__leading", count: 0
  end
end
