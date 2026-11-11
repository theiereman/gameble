require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

# A banned or deleted player's market presence is dropped by the minute job, and the players left behind see it.
class MarketRemovedPlayersSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @leader = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    fund!(@leader, 100_000)
    bid(@leader, 30_000)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "a banned leader's bid is voided: the Annonce shows the line and the seller's bell leads to MES VENTES" do
    @leader.update_columns(banned_at: Time.current)
    Game::Market::DropPresenceJob.perform_now
    sign_in_through_the_site(@seller)

    visit market_listing_path(locale: :en, token: @listing.token)

    assert_selector ".market-history__line--voided", text: "Bid voided: player removed"
    find(".bell__button").click
    within("#bell-panel") do
      assert_selector ".bell__line", text: /The leading player on Tin Soldier was removed\./
      click_link href: market_my_sales_path(locale: :en)
    end
    assert_current_path market_my_sales_path(locale: :en)
  end

  test "a banned seller's listing is withdrawn: the leader's bell shows the line and the Annonce says it was withdrawn" do
    @seller.update_columns(banned_at: Time.current)
    Game::Market::DropPresenceJob.perform_now
    sign_in_through_the_site(@leader)

    find(".bell__button").click
    within("#bell-panel") do
      assert_selector ".bell__line", text: /Tin Soldier was withdrawn from the market\./
      click_link href: market_listing_path(locale: :en, token: @listing.token)
    end

    assert_text "LISTING WITHDRAWN"
    assert_equal [ 100_000, 0 ], figures(@leader)
  end

  test "a player leading an auction sees the delete dialog name the balance, and once deleted the job voids the lead and forfeits it" do
    sign_in_through_the_site(@leader)
    visit settings_path(locale: :en)
    click_on "Delete my account"
    assert_selector "#delete-dialog-market", text: /Your balance of\s+100,000\s+PiCoins is destroyed without refund/

    @leader.update_columns(deleted_at: Time.current, steam_id: nil)
    Game::Market::DropPresenceJob.perform_now

    assert_equal [ 0, 0 ], figures(@leader)
    assert_nil @listing.reload.leader_id
    assert_equal 1, Game::Market::LedgerEntry.where(player_id: @leader.id, kind: "forfeit").count
  end
end
