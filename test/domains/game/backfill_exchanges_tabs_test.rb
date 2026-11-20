require "test_helper"
require_relative "../../support/rake_tasks"

# Game::BackfillExchangesTabs: both parties of an accepted friend trade closed in the last 30 days keep the exchanges on
# between friends, unless they already chose a sub-tab; each run publishes one event. game:backfill_exchanges_tabs runs it.
class Game::BackfillExchangesTabsTest < ActiveSupport::TestCase
  include RakeTasks
  NOW = Time.zone.parse("2026-11-20 12:00")

  setup do
    rake_task("game:backfill_exchanges_tabs")
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @other = accounts_players(:administrator)
  end

  def backfill = Game::BackfillExchangesTabs.new.call(now: NOW)

  def trade(from, to, status: "accepted", closed_at: NOW - 3.days)
    low, high = [ from.id, to.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: from.id, recipient_id: to.id, status:,
      proposed_at: closed_at || NOW - 1.hour, expires_at: (closed_at || NOW) + 7.days, closed_at:)
  end

  def tab(player) = Game::PlayerState.where(player_id: player.id).pick(:exchanges_tab)

  def events = Rails.configuration.event_store.read.stream(Game::ExchangesTabsBackfilled::STREAM).to_a

  test "both parties of a recent accepted trade keep between friends, with or without a state row, in one event" do
    Game::PlayerState.where(player_id: @friend.id).delete_all
    trade(@player, @friend)

    assert_equal 2, backfill.value!

    assert_equal "friends", tab(@player)
    assert_equal "friends", tab(@friend)
    assert_equal Game::PlayerState.markers_at_published_season.stringify_keys,
      Game::PlayerState.find_by!(player_id: @friend.id).attributes.slice("allocation_received_season", "allocation_seen_season")
    assert_equal 1, events.size
    assert_equal "friends", Game::ExchangesTab.call(@friend)
  end

  test "a trade accepted more than 30 days ago leaves the market as the default" do
    trade(@player, @friend, closed_at: NOW - 31.days)

    assert_equal 0, backfill.value!

    assert_nil tab(@player)
    assert_equal "market", Game::ExchangesTab.call(@player)
  end

  test "a recent trade declined, expired or still open is left alone" do
    trade(@player, @friend, status: "declined")
    trade(@player, @other, status: "expired")
    trade(@friend, @other, status: "open", closed_at: nil)

    assert_equal 0, backfill.value!

    assert_nil tab(@player)
    assert_nil tab(@friend)
    assert_nil tab(@other)
  end

  test "a sub-tab already chosen is never overwritten" do
    Game::PlayerState.where(player_id: @player.id).update_all(exchanges_tab: "market")
    trade(@player, @friend)

    assert_equal 1, backfill.value!

    assert_equal "market", tab(@player)
    assert_equal "friends", tab(@friend)
  end

  test "a deleted player is left alone" do
    @friend.update_columns(deleted_at: NOW - 1.day, steam_id: nil)
    trade(@player, @friend)

    assert_equal 1, backfill.value!

    assert_equal "friends", tab(@player)
    assert_nil tab(@friend)
  end

  test "a second run changes nothing and counts no one" do
    trade(@player, @friend)
    backfill.value!

    assert_no_changes -> { Game::PlayerState.order(:player_id).pluck(:player_id, :exchanges_tab, :updated_at) } do
      assert_equal 0, backfill.value!
    end
    assert_equal 2, events.size
  end

  test "the rake task runs the backfill now and prints how many players keep between friends" do
    trade(@player, @friend, closed_at: Time.current - 3.days)

    out, = capture_io { rake_task("game:backfill_exchanges_tabs").execute }

    assert_match "2 player(s)", out
    assert_equal "friends", tab(@player)
    assert_equal "friends", tab(@friend)
  end
end
