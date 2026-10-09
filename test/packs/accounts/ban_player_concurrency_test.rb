require "test_helper"

# A ban against a trade acceptance between the banned player and a friend.
# Each thread has its own connection, so the test commits for real; it uses
# players of its own and removes them afterwards.
class Accounts::BanPlayerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @moderator = accounts_players(:moderator)
    @target = Accounts::Player.create!(steam_id: "76561197960380001")
    @friend = Accounts::Player.create!(steam_id: "76561197960380002")
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    low, high = [ @target.id, @friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: @target.id, card_season_id: @portal, quantity: 2)
    Game::Holding.create!(player_id: @friend.id, card_season_id: @depths, quantity: 2)
    @trade = Game::ProposeTrade.new.call(player: @target, recipient: @friend, offer: { @portal => 1 }, request: { @depths => 1 }).value!
  end

  teardown do
    ids = [ @target.id, @friend.id ]
    trades = Game::Trade.where(proposer_id: ids).or(Game::Trade.where(recipient_id: ids)).ids
    Game::TradeItem.where(trade_id: trades).delete_all
    Game::Trade.where(id: trades).delete_all
    Game::Friendship.where(low_player_id: ids).or(Game::Friendship.where(high_player_id: ids)).delete_all
    [ Game::Holding, Game::SetCompletion, Game::PlayerState, Game::FeedEntry ].each { |model| model.where(player_id: ids).delete_all }
    connection = ActiveRecord::Base.connection
    streams = ids.flat_map { |id| [ Game::Operation.stream_name(id), "Accounts::Player$#{id}" ] }
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Accounts::Player.where(id: ids).delete_all
  end

  # Runs `first` in a transaction that stays open until `second`, started on
  # another connection, waits on a lock; then commits it. Returns both
  # results.
  def first_holding_the_lock(first, second)
    held = Queue.new
    release = Queue.new
    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          first.call
        ensure
          held << true
          release.pop
        end
      end
    end
    held.pop
    second_thread = Thread.new { ActiveRecord::Base.connection_pool.with_connection { second.call } }
    begin
      wait_for_a_lock_wait
    ensure
      release << true
      results = [ first_thread.value, second_thread.value ]
    end
    results
  end

  def wait_for_a_lock_wait
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    waiting = "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock'"
    until ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value(waiting) }.positive?
      raise "the second operation never waited on a lock" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.01
    end
  end

  def ban = -> { Accounts::BanPlayer.new.call(staff: @moderator, player: Accounts::Player.find(@target.id)) }

  def accept(friend = Accounts::Player.find(@friend.id)) = -> { Game::AcceptTrade.new.call(player: friend, trade_id: @trade.id, seen: @trade.proposed_at) }

  def reserved(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)&.reserved

  test "an acceptance that commits first: the ban then finds the trade closed and drops the friendship" do
    acceptance, banning = first_holding_the_lock(accept, ban)

    assert acceptance.success?
    assert banning.success?
    assert_equal "accepted", @trade.reload.status
    assert_predicate @target.reload, :banned?
    assert_not Game::FriendshipBetween.call(@target, @friend)
    assert_equal 0, reserved(@target, @portal)
  end

  test "an acceptance that waits on the ban finds the trade cancelled" do
    friend = Accounts::Player.find(@friend.id)

    banning, acceptance = first_holding_the_lock(ban, accept(friend))

    assert banning.success?
    assert_equal Dry::Monads::Failure(:trade_not_open), acceptance
    assert_equal "cancelled", @trade.reload.status
    assert_equal 0, reserved(@target, @portal)
    assert_equal [ 2, 2 ], [ Game::Holding.find_by(player_id: @target.id, card_season_id: @portal).quantity,
      Game::Holding.find_by(player_id: @friend.id, card_season_id: @depths).quantity ]
  end
end
