require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_sales"

class Game::Market::MarketAchievementsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSales
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(increment_basis_points: 500)
  end

  def metric(name, player) = Game::AchievementProgress.call(player, [ name ]).fetch(name)
  def grant(key, player) = Game::GrantAchievement.new.call(player:, achievement: key)
  def unlocked(player) = Game::AchievementUnlock.where(player_id: player.id).pluck(:achievement)
  def rival(name) = Accounts::Player.create!(steam_id: "76561197960288#{name.sum % 1000}", persona_name: name)

  def auction!(card: @card, starting_price: 20_000)
    hold(@seller, card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: card, starting_price:, ends_at: 1.day.from_now)
  end

  def bids!(*placed)
    placed.each { |player, maximum| assert bid(player, maximum).success? }
  end

  def close!
    @listing.update_columns(ends_at: 1.minute.ago)
    assert Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id).success?
  end

  def bought!(card, price, buyer: @seller, sold_at: 2.days.ago) = sold!(card, price, seller: @first, buyer:, sold_at:)
  def resold!(card, price, seller: @seller) = sold!(card, price, seller:, buyer: @second)

  test "winning an auction after losing the lead twice grants Hostile Takeover" do
    [ @first, @second ].each { fund!(it, 200_000) }
    auction!
    bids!([ @first, 25_000 ], [ @second, 30_000 ], [ @first, 35_000 ], [ @second, 40_000 ], [ @first, 50_000 ])
    close!

    assert_equal %w[outbid outbid won], outcomes(@first).sort
    assert_equal 1, metric(:comeback_wins, @first)
    assert_equal :hostile_takeover, grant(:hostile_takeover, @first).value!.key
  end

  test "beaten bids are no lost lead, and two lost leads on an auction someone else won are no comeback" do
    [ @first, @second ].each { fund!(it, 200_000) }
    auction!
    bids!([ @second, 50_000 ], [ @first, 25_000 ], [ @first, 30_000 ], [ @first, 60_000 ], [ @second, 70_000 ], [ @first, 80_000 ])
    close!

    assert_equal %w[beaten beaten outbid won], outcomes(@first).sort
    assert_equal 0, metric(:comeback_wins, @first)
    assert_equal :not_reached, grant(:hostile_takeover, @first).failure
    assert_equal 2, outcomes(@second).count("lost")
    assert_equal 0, metric(:comeback_wins, @second)
  end

  test "a lead lost to a moderation void is no comeback, even when the bidder later wins" do
    [ @first, @second ].each { fund!(it, 200_000) }
    auction!
    bids!([ @first, 25_000 ])
    @first.update_columns(banned_at: Time.current)
    assert Game::Market::VoidLead.new.call(player: @seller, listing_id: @listing.id).success?
    @first.update_columns(banned_at: nil)
    bids!([ @second, 30_000 ], [ @first, 35_000 ], [ @second, 40_000 ], [ @first, 50_000 ])
    close!

    assert_equal %w[outbid outbid voided won], outcomes(@first).sort
    assert_equal 0, metric(:comeback_wins, @first)
  end

  test "a sale that drew bids from three players grants Competitive Tender to its seller" do
    third = rival("Third")
    [ @first, @second, third ].each { fund!(it, 200_000) }
    auction!
    bids!([ @first, 25_000 ], [ @second, 30_000 ], [ third, 40_000 ], [ third, 60_000 ])
    close!

    assert_includes outcomes(third), "raise"
    assert_equal 3, metric(:most_bidders_on_a_sale, @seller)
    assert_equal :competitive_tender, grant(:competitive_tender, @seller).value!.key
  end

  test "a bidder whose lead was voided is not counted among a sale's bidders" do
    third = rival("Third")
    [ @first, @second, third ].each { fund!(it, 200_000) }
    auction!
    bids!([ @first, 25_000 ], [ @second, 30_000 ], [ third, 40_000 ])
    third.update_columns(banned_at: Time.current)
    assert Game::Market::VoidLead.new.call(player: @seller, listing_id: @listing.id).success?
    bids!([ @first, 45_000 ])
    close!

    assert_equal %w[lost voided], outcomes(third).sort
    assert_equal 2, metric(:most_bidders_on_a_sale, @seller)
    assert_equal :not_reached, grant(:competitive_tender, @seller).failure
  end

  test "an edition resold for twice its purchase price grants Capital Gain" do
    bought!(@card, 5_000)
    resold!(@card, 10_000)

    assert_equal 1, metric(:doubled_resales, @seller)
    assert_equal :capital_gain, grant(:capital_gain, @seller).value!.key
  end

  test "a resale just under double, or listed before the purchase settled, is no doubled resale" do
    bought!(@card, 5_000)
    resold!(@card, 9_999)
    other = catalog_card_seasons(:rare_card_one)
    bought!(other, 5_000, sold_at: 1.hour.ago)
    resold!(other, 20_000).update_columns(created_at: 2.hours.ago)

    assert_equal 0, metric(:doubled_resales, @seller)
    assert_equal :not_reached, grant(:capital_gain, @seller).failure
  end

  test "another player's purchase of the edition does not count as the seller's" do
    bought!(@card, 5_000, buyer: @second)
    resold!(@card, 10_000)

    assert_equal 0, metric(:doubled_resales, @seller)
  end

  test "one cheap purchase counts once however many copies of the edition are resold" do
    bought!(@card, 5_000)
    3.times { resold!(@card, 10_000 + it) }

    assert_equal 1, metric(:doubled_resales, @seller)
  end

  test "twenty-five cards sold grant Quarterly Targets Met, unsold listings aside" do
    24.times { resold!(@card, 1_300) }
    listing!(seller: @seller, card_season: @card, status: "unsold", ends_at: 1.hour.ago)

    assert_equal :not_reached, grant(:quarterly_targets_met, @seller).failure
    resold!(@card, 1_300)
    assert_equal :quarterly_targets_met, grant(:quarterly_targets_met, @seller).value!.key
  end

  test "a settled sale checks the achievements of its seller and its winner" do
    fund!(@first, 50_000)
    auction!
    lead!(@listing, @first, 40_000, price: 30_000)

    close!

    granted = enqueued_jobs.select { it[:job] == Game::GrantAchievementsJob }.map { it[:args].first }
    assert_equal [ @seller.id, @first.id ].sort, granted.sort
  end

  test "the fifth doubled resale grants Insider Trading at settlement and opens the Executive avatar" do
    %i[portal_one uncommon_card_one rare_card_one common_card_one].each do |fixture|
      card = catalog_card_seasons(fixture)
      bought!(card, 5_000)
      resold!(card, 10_000)
    end
    final = catalog_card_seasons(:legendary_card_one)
    bought!(final, 5_000)
    fund!(@first, 50_000)
    auction!(card: final, starting_price: 10_000)
    lead!(@listing, @first, 12_000, price: 10_000)
    assert_equal :avatar_locked, Game::ChooseAvatar.new.call(player: @seller, avatar: "executive").failure

    perform_enqueued_jobs(only: Game::GrantAchievementsJob) { close! }

    assert_includes unlocked(@seller), "insider_trading"
    assert Game::ChooseAvatar.new.call(player: @seller, avatar: "executive").success?
  end

  test "the Insider Trading tile counts doubled resales toward five" do
    %i[portal_one uncommon_card_one rare_card_one].each do |fixture|
      card = catalog_card_seasons(fixture)
      bought!(card, 5_000)
      resold!(card, 10_000)
    end

    tile = Game::AchievementBoard.call(@seller).find { it.key == :insider_trading }

    assert_equal [ 3, 5, false ], [ tile.progress, tile.threshold, tile.earned ]
  end

  test "the market achievements show on the board while the market is closed" do
    close_market!

    keys = Game::AchievementBoard.call(@seller).map(&:key)

    assert_equal %i[hostile_takeover competitive_tender capital_gain quarterly_targets_met insider_trading], keys.last(5)
  end
end
