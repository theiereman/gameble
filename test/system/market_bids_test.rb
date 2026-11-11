require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

class MarketBidsSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:administrator)
    @rival = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @bidder, @rival ].each { fund!(it, 200_000) }
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "a player is outbid, raises from the field RELEVER focuses, then finds the lost auction under TERMINÉES RÉCEMMENT" do
    assert bid(@bidder, 30_000).success?
    sign_in_through_the_site(@bidder)

    visit market_my_bids_path(locale: :en)
    assert_selector ".market-row__chip", text: "LEADING"

    assert bid(@rival, 60_000).success?
    visit market_my_bids_path(locale: :en)
    assert_selector ".market-row__chip", text: "OUTBID"
    assert_selector ".market-row__fact dd", text: "30,000"

    find("a[aria-label='Raise, Tin Soldier']").click
    assert_selector "h1#market-listing-heading", text: "Tin Soldier"
    assert_selector "#annonce-maximum:focus"

    @listing.update_columns(ends_at: 1.minute.ago)
    assert Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id).success?

    visit market_my_bids_path(locale: :en)
    assert_selector "#my-bids-recent-heading", text: "FINISHED RECENTLY"
    assert_selector "section[aria-labelledby=my-bids-recent-heading] .market-row__chip", text: "LOST"
    assert_no_selector "section[aria-labelledby=my-bids-recent-heading] .market-row__action"
  end
end
