require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

# A player outbid from another session sees the bell line live, and the Annonce it leads to opens with the outbid panel.
class MarketOutbidSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @outbid = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @rival.update!(persona_name: "Rival")
    @card = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @outbid, @rival ].each { fund!(it, 100_000) }
    bid(@outbid, 30_000)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "the outbid player's bell shows the line live and the Annonce opens with the panel above an empty field" do
    sign_in_through_the_site(@outbid)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    page.execute_script("window.localStorage.clear()")

    bid(@rival, 40_000)
    perform_enqueued_jobs(only: PlayerStreamJob)

    find(".bell__button").click
    assert_selector "#bell-panel:popover-open"
    within("#bell-panel") do
      assert_selector ".bell__line", text: /Rival went past your maximum on Tin Soldier\./
      click_link href: market_listing_path(locale: :en, token: @listing.token)
    end

    assert_selector "#annonce-outbid h2", text: "YOU WERE OUTBID"
    assert_text "Rival moved ahead on Tin Soldier."
    assert_field "annonce-maximum", with: ""
    assert_no_selector "#annonce-bid #annonce-outbid:focus"
  end
end
