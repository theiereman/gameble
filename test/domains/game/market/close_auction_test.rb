require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"

class Game::Market::CloseAuctionTest < ActiveSupport::TestCase
  include SingletonStub

  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @winner = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!(commission_basis_points: 1_000)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.minute.ago)
    fund!(@winner, 50_000)
  end

  def lead(maximum: 40_000, price: 31_500) = lead!(@listing, @winner, maximum, price:)

  def close(listing = @listing, player: @seller) = Game::Market::CloseAuction.new.call(player:, listing_id: listing.id)

  def wallet(player) = Game::Market::Wallet.find_by!(player_id: player.id)

  def holding(player) = Game::Holding.find_by(player_id: player.id, card_season_id: @card.id)

  def figures(player) = wallet(player).attributes.values_at("available", "committed")

  def copies(player) = holding(player).attributes.values_at("quantity", "reserved")

  def kinds(player) = Game::Market::LedgerEntry.where(listing_id: @listing.id, player_id: player.id).order(:id).pluck(:kind)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) }, -> { Game::Holding.sum(:reserved) } ], &)
  end

  def events(type) = Rails.configuration.event_store.read.of_type(type).to_a

  test "the worked example sells at the current price and settles every wallet" do
    lead
    destroyed = Game::Market::ReconcileWallets.call.destroyed

    assert close.success?

    assert_equal [ 18_500, 0 ], figures(@winner)
    assert_equal 28_350, wallet(@seller).available
    assert_equal destroyed + 3_150, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
    assert_equal %w[sold], [ @listing.reload.status ]
    assert_equal 31_500, @listing.final_price
    assert_equal 31_500, @listing.average_after_sale
    assert_equal [ @winner.id, 40_000 ], [ @listing.leader_id, @listing.leader_maximum ]
  end

  test "a listing settled after bids placed through the operation has no leading bid" do
    @listing.update!(ends_at: 1.day.from_now)
    other = accounts_players(:administrator)
    fund!(other, 50_000)
    Game::Market::PlaceBid.new.call(player: other, listing_id: @listing.id, maximum: 25_000)
    Game::Market::PlaceBid.new.call(player: @winner, listing_id: @listing.id, maximum: 40_000)
    @listing.update_columns(ends_at: 1.minute.ago)

    assert close.success?

    assert_empty Game::Market::Bid.where(listing_id: @listing.id, outcome: "leading")
    assert_equal [ "won" ], Game::Market::Bid.where(listing_id: @listing.id, player_id: @winner.id).pluck(:outcome)
    assert_equal [ "lost" ], Game::Market::Bid.where(listing_id: @listing.id, player_id: other.id).pluck(:outcome)
  end

  test "the copy moves with its reservation and the winner receives it" do
    lead

    close

    assert_equal [ 0, 0 ], copies(@seller)
    assert_equal [ 1, 0 ], copies(@winner)
  end

  test "the winner's pending allocation is received once the sale settles" do
    lead
    received = []
    receiver = Object.new
    receiver.define_singleton_method(:call) { |player:, season:| received << player.id and Dry::Monads::Success([]) }

    stub_singleton(Game::ReceiveSeasonAllocation, :new, ->(*) { receiver }) { close }

    assert_equal [ @winner.id ], received
  end

  test "entries are written per wallet and zero amounts are skipped" do
    lead(maximum: 31_500)
    close

    assert_equal %w[hold purchase], kinds(@winner)
    assert_equal %w[sale commission], kinds(@seller)
  end

  test "a zero commission writes no commission entry" do
    @listing.update!(settings_id: open_market!(commission_basis_points: 0).id)
    lead

    close

    assert_equal %w[sale], kinds(@seller)
  end

  test "the commission reads the settings version of the listing" do
    lead
    open_market!(commission_basis_points: 2_000)

    close

    assert_equal 28_350, wallet(@seller).available
  end

  test "a set tier reached by the copy is recorded as a trade" do
    lead
    stub_singleton(Game::SetTier, :record, ->(**arguments) { Thread.current[:tier_args] = arguments; {} }) { close }

    assert_equal "trade", Thread.current[:tier_args][:reached_by]
    assert_equal [ @card.id ], Thread.current[:tier_args][:card_season_ids]
  end

  test "the seller's showcase entry for the sold copy is removed" do
    lead
    Game::ShowcaseEntry.create!(player_id: @seller.id, card_season_id: @card.id, position: 0)

    close

    assert_not Game::ShowcaseEntry.exists?(player_id: @seller.id, card_season_id: @card.id)
  end

  test "one sold event carries identifiers and amounts" do
    lead

    assert_difference -> { events(Game::Market::AuctionSold).size }, 1 do
      close
    end

    data = events(Game::Market::AuctionSold).last.data
    assert_equal({ listing_id: @listing.id, seller_id: @seller.id, winner_id: @winner.id, card_season_id: @card.id, final_price: 31_500, surplus: 8_500,
      outbid_player_id: nil, outbid_released: 0 }, data)
  end

  test "no leader leaves the listing unsold and releases the reservation" do
    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      assert close.success?
    end

    assert_equal "unsold", @listing.reload.status
    assert_equal 0, holding(@seller).reserved
    assert_equal 1, events(Game::Market::AuctionUnsold).size
  end

  test "a removed seller withdraws the listing and releases the leader's maximum" do
    lead
    @seller.update_columns(banned_at: Time.current)

    assert close.success?

    assert_equal [ "withdrawn", nil, nil ], @listing.reload.attributes.values_at("status", "leader_id", "leader_maximum")
    assert_equal [ 50_000, 0 ], figures(@winner)
    assert_equal [ 1, 0 ], copies(@seller)
    assert_equal({ listing_id: @listing.id, seller_id: @seller.id, leader_id: @winner.id, released: 40_000 }, events(Game::Market::ListingWithdrawn).last.data)
  end

  test "a deleted seller withdraws the listing" do
    lead
    @seller.update_columns(deleted_at: Time.current, steam_id: nil)

    close

    assert_equal "withdrawn", @listing.reload.status
  end

  %i[banned_at deleted_at].each do |column|
    test "a leader removed by #{column} leaves the listing unsold and releases the maximum" do
      lead
      @winner.update_columns(column => Time.current, **(column == :deleted_at ? { steam_id: nil } : {}))

      assert close.success?

      assert_equal [ "unsold", nil ], [ @listing.reload.status, @listing.leader_id ]
      assert_equal [ 50_000, 0 ], figures(@winner)
      assert_equal 0, holding(@seller).reserved
      assert_equal 1, events(Game::Market::AuctionUnsold).size
    end
  end

  test "both removed: the seller's withdrawal wins" do
    lead
    @seller.update_columns(banned_at: Time.current)
    @winner.update_columns(deleted_at: Time.current, steam_id: nil)

    close

    assert_equal "withdrawn", @listing.reload.status
    assert_equal 50_000, wallet(@winner).available
  end

  test "a second run changes nothing" do
    lead
    close

    nothing_moves do
      assert_equal Game::Market::CloseAuction::CLOSED_MEANWHILE, close
    end
  end

  test "a listing not due yet is left alone" do
    lead
    @listing.update!(ends_at: 1.minute.from_now)

    nothing_moves { assert_equal :listing_not_closable, close.failure }
    assert_equal "open", @listing.reload.status
  end

  test "a leader changed since the unlocked read leaves everything as it was" do
    lead
    seen = Game::Market::Listing.find(@listing.id)
    stub_singleton(Game::Market::Listing, :find_by, ->(*, **) { seen }) do
      @listing.update!(leader_id: @seller.id)
      nothing_moves { assert_equal :listing_not_closable, close.failure }
    end
  end

  test "another seller or an unknown listing is not found" do
    assert_equal :listing_not_found, close(player: @winner).failure
    assert_equal :listing_not_found, Game::Market::CloseAuction.new.call(player: @seller, listing_id: 0).failure
  end

  test "a deadlock answers market busy" do
    lead
    stub_singleton(Game::TradeLocks, :players, ->(*) { raise ActiveRecord::Deadlocked }) do
      assert_equal :market_busy, close.failure
    end
    assert_equal "open", @listing.reload.status
  end

  test "a due auction settles while the market is closed" do
    lead
    close_market!(first_opened_at: 1.day.ago)

    assert close.success?

    assert_equal "sold", @listing.reload.status
    assert Game::Market::ReconcileWallets.call.balanced?
  end
end
