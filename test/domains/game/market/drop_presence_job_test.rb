require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"

class Game::Market::DropPresenceJobTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @leader = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    @other_card = catalog_card_seasons(:portal_one)
    open_market!
    [ @card, @other_card ].each { hold(@seller, it.id, 1, reserved: 1) }
    fund!(@leader, 100_000)
  end

  def led(card) = listing!(seller: @seller, card_season: card, ends_at: 1.day.from_now).tap { lead!(it, @leader, 30_000) }

  test "every listing led by a removed player is voided in one pass" do
    first = led(@card)
    second = led(@other_card)
    @leader.update_columns(banned_at: Time.current)

    Game::Market::DropPresenceJob.perform_now

    assert_equal [ nil, nil ], [ first, second ].map { it.reload.leader_id }
    assert_equal [ 100_000, 0 ], Game::Market::Wallet.find_by!(player_id: @leader.id).attributes.values_at("available", "committed")
  end

  test "a present leader and an ended listing are left alone" do
    present = led(@card)
    ended = led(@other_card).tap { it.update_columns(ends_at: 1.minute.ago) }
    @leader.update_columns(banned_at: Time.current)
    present.update_columns(leader_id: accounts_players(:administrator).id)

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      assert_no_error_reported { Game::Market::DropPresenceJob.perform_now }
    end

    assert_equal [ true, true ], [ present, ended ].map { it.reload.leader_id.present? }
  end

  test "a listing that raises does not stop the others and is reported with its id" do
    first = led(@card)
    second = led(@other_card)
    @leader.update_columns(banned_at: Time.current)
    original = Game::Market::VoidLead.instance_method(:call)
    failing = ->(**arguments) { arguments[:listing_id] == first.id ? raise("boom") : original.bind(Game::Market::VoidLead.new).call(**arguments) }

    report = assert_error_reported(RuntimeError) do
      Game::Market::VoidLead.stub(:new, -> { Struct.new(:call).new(failing) }) { Game::Market::DropPresenceJob.perform_now }
    end

    assert_equal first.id, report.context[:listing_id]
    assert_equal [ @leader.id, nil ], [ first, second ].map { it.reload.leader_id }
  end

  test "a listing of a removed seller led by a removed player is withdrawn first, so no lead is voided" do
    listing = led(@card)
    @seller.update_columns(banned_at: Time.current)
    @leader.update_columns(banned_at: Time.current)

    Game::Market::DropPresenceJob.perform_now

    assert_equal "withdrawn", listing.reload.status
    assert_equal 0, Game::Market::Bid.where(listing_id: listing.id, outcome: "voided").count
    assert_equal 1, Game::Market::LedgerEntry.where(listing_id: listing.id, kind: "release").count
    assert_equal [ 100_000, 0 ], Game::Market::Wallet.find_by!(player_id: @leader.id).attributes.values_at("available", "committed")
  end

  test "a deleted player's balance is forfeited after the listings are withdrawn and the leads voided, in the same pass" do
    listing = led(@card)
    @leader.update_columns(deleted_at: Time.current, steam_id: nil)

    Game::Market::DropPresenceJob.perform_now

    assert_equal [ nil, 0, 0 ], [ listing.reload.leader_id, *Game::Market::Wallet.find_by!(player_id: @leader.id).attributes.values_at("available", "committed") ]
    assert_equal 100_000, Game::Market::LedgerEntry.where(player_id: @leader.id, kind: "forfeit").sole.available_delta.abs
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a banned player's wallet is never forfeited" do
    @leader.update_columns(banned_at: Time.current)

    Game::Market::DropPresenceJob.perform_now

    assert_equal [ 100_000, 0 ], Game::Market::Wallet.find_by!(player_id: @leader.id).attributes.values_at("available", "committed")
    assert_equal 0, Game::Market::LedgerEntry.where(kind: "forfeit").count
  end

  test "a retention-deleted player's balance is forfeited like any other" do
    @leader.update_columns(deleted_at: Time.current, steam_id: nil)

    Game::Market::DropPresenceJob.perform_now

    assert_equal 0, Game::Market::Wallet.find_by!(player_id: @leader.id).available
  end

  test "a wallet that raises is reported with the player and the others go on" do
    @leader.update_columns(deleted_at: Time.current, steam_id: nil)
    other = accounts_players(:administrator).tap { it.update_columns(deleted_at: Time.current, steam_id: nil) }
    fund!(other, 700)
    original = Game::Market::ForfeitBalance.instance_method(:call)
    failing = ->(**arguments) { arguments[:player] == @leader ? raise("boom") : original.bind(Game::Market::ForfeitBalance.new).call(**arguments) }

    report = assert_error_reported(RuntimeError) do
      Game::Market::ForfeitBalance.stub(:new, -> { Struct.new(:call).new(failing) }) { Game::Market::DropPresenceJob.perform_now }
    end

    assert_equal @leader.id, report.context[:player_id]
    assert_equal 0, Game::Market::Wallet.find_by!(player_id: other.id).available
  end

  test "a second run changes nothing" do
    led(@card)
    @leader.update_columns(banned_at: Time.current)
    Game::Market::DropPresenceJob.perform_now

    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Market::Bid.count } ]) do
      assert_no_error_reported { Game::Market::DropPresenceJob.perform_now }
    end
  end
end
