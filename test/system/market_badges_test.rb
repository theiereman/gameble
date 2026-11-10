require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

class MarketBadgesSystemTest < ApplicationSystemTestCase
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
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500)
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

  test "the badge and the balance follow an outbid on the hub and the badge goes when the player raises" do
    sign_in_through_the_site(@outbid)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_no_selector "#menu-market-badge .menu-item__badge"

    bid(@rival, 40_000)
    perform_enqueued_jobs(only: PlayerStreamJob)

    assert_selector "#menu-market-badge .menu-item__badge", text: "1"
    assert_selector "#tab-market-badge .tab-bar__badge", text: "1", visible: :all
    assert_selector ".balance-chip .balance-chip__available[aria-label='100,000 PiCoins']", match: :first

    bid(@outbid, 60_000)
    perform_enqueued_jobs(only: PlayerStreamJob)

    assert_no_selector "#menu-market-badge .menu-item__badge"
    assert_no_selector "#tab-market-badge .tab-bar__badge", visible: :all
  end

  test "an outbid posts its line to the polite region present on the page" do
    sign_in_through_the_site(@outbid)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    bid(@rival, 40_000)
    perform_enqueued_jobs(only: PlayerStreamJob)

    assert_selector "#market-status [role=status]", text: "Rival went past your maximum on Tin Soldier.", visible: :all
  end
end
