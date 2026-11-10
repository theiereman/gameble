require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::VoidLeadTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @leader = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(increment_basis_points: 500)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @leader, @rival ].each { fund!(it, 100_000) }
    bid(@leader, 30_000)
  end

  def ban(player = @leader) = player.update_columns(banned_at: Time.current)

  def delete(player = @leader) = player.update_columns(deleted_at: Time.current)

  def void(listing = @listing) = Game::Market::VoidLead.new.call(player: @seller, listing_id: listing.id)

  test "a banned leader's maximum is released and the auction restarts at its starting price with the same end" do
    ends_at = @listing.reload.ends_at
    ban

    assert void.success?

    assert_equal [ 100_000, 0 ], figures(@leader)
    assert_equal [ nil, nil, 20_000, ends_at ], @listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price", "ends_at")
    assert_equal %w[outbid voided], outcomes(@leader)
    voided = Game::Market::Bid.find_by!(listing: @listing, outcome: "voided")
    assert_equal [ 30_000, 20_000 ], [ voided.maximum, voided.price_after ]
    assert_equal %w[hold release], entries_of.where(player_id: @leader.id).pluck(:kind)
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "it publishes one event on the seller's stream and writes the seller's notice" do
    ban

    assert_difference -> { events(Game::Market::LeadVoided).size }, 1 do
      void
    end

    assert_equal({ listing_id: @listing.id, seller_id: @seller.id, leader_id: @leader.id, released: 30_000 }, events(Game::Market::LeadVoided).last.data)
    assert_equal "lead_voided", Game::Market::Notice.find_by!(player_id: @seller.id, listing_id: @listing.id).kind
  end

  test "a deleted leader is voided without a notice for the removed player" do
    delete

    assert void.success?

    assert_equal [ 100_000, 0 ], figures(@leader)
    assert_nil Game::Market::Notice.find_by(player_id: @leader.id)
  end

  test "a removed seller and a removed leader release once and write no notice" do
    ban
    delete(@seller)

    assert void.success?

    assert_equal [ 100_000, 0 ], figures(@leader)
    assert_equal 1, entries_of.where(kind: "release").count
    assert_nil Game::Market::Notice.find_by(player_id: @seller.id)
  end

  test "a second run finds no leader and posts nothing" do
    ban
    assert void.success?

    nothing_changes { assert_equal Game::Market::VoidLead::LEAD_NOT_VOIDABLE, void }
  end

  test "a present leader is not voided" do
    nothing_changes { assert_equal Game::Market::VoidLead::LEAD_NOT_VOIDABLE, void }
  end

  test "an ended or closed listing is left to the close" do
    ban
    @listing.update_columns(ends_at: 1.minute.ago)
    nothing_changes { assert_equal Game::Market::VoidLead::LEAD_NOT_VOIDABLE, void }

    @listing.update_columns(ends_at: 1.day.from_now, status: "cancelled")
    nothing_changes { assert_equal Game::Market::VoidLead::LEAD_NOT_VOIDABLE, void }
  end

  test "the next bid starts at the starting price against nobody" do
    ban
    assert void.success?

    answer = bid(@rival, 20_000).value!

    assert_equal [ 20_000, @rival.id ], [ answer.price, @listing.reload.leader_id ]
    assert_equal 1, entries_of.where(player_id: @leader.id, kind: "release").count
  end

  test "the history keeps the voided line for every viewer without a name" do
    ban
    assert void.success?

    lines = Game::Market::BidHistory.call(token: @listing.token, viewer: nil)

    assert_equal %i[voided bid created], lines.map(&:kind)
    assert_nil lines.first.player
  end
end
