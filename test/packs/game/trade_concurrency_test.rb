require "test_helper"

# The trade operations under concurrency (AD-6, AD-8, AD-10): the bank locks
# taken in ascending player id, then the holdings in ascending card-season,
# serialise proposals that touch the same player, so a card is never
# reserved beyond what is owned and crossing trades never deadlock. Each
# thread has its own connection, so the test commits for real and cleans up
# after itself.
class Game::TradeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @card = catalog_card_seasons(:portal_one).id
    @other = catalog_card_seasons(:rare_card_one).id
    @players = [ @alice, @bob, @carol ]
  end

  teardown do
    Game::TradeItem.delete_all
    Game::Trade.delete_all
    Game::Holding.where(player_id: @players.map(&:id)).delete_all
    Game::Friendship.delete_all
    Accounts::Player.where(id: @created.map(&:id)).delete_all if @created
    streams = @players.map { |player| Game::Operation.stream_name(player.id) }
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  def reserved(player, card_season_id) = Game::Holding.uncached { Game::Holding.find_by!(player_id: player.id, card_season_id:).reserved }

  # Runs the blocks together, each on its own connection, released at once.
  # A deadlock would hang the threads: a timeout fails the test instead.
  def together(*blocks)
    gate = Queue.new
    threads = blocks.map do |block|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          block.call
        end
      end
    end
    blocks.size.times { gate << :go }
    threads.map { |thread| thread.join(20) ? thread.value : flunk("a thread is stuck: deadlock") }
  end

  def propose(from, to, offer, request)
    -> { Game::ProposeTrade.new.call(player: Accounts::Player.find(from.id), recipient: Accounts::Player.find(to.id), offer:, request:) }
  end

  test "two proposals of the same copies to two friends at once: one reserves them, the other is refused" do
    befriend(@alice, @bob)
    befriend(@alice, @carol)
    hold(@alice, @card, 2)

    results = together(propose(@alice, @bob, { @card => 2 }, { @other => 1 }), propose(@alice, @carol, { @card => 2 }, { @other => 1 }))

    assert_equal 1, results.count(&:success?)
    assert_equal [ :insufficient_copies ], results.select(&:failure?).map(&:failure)
    assert_equal 2, reserved(@alice, @card)
    assert_equal 1, Game::Trade.count
  end

  test "many proposals of single copies at once never reserve more than owned" do
    friends = Array.new(5) { |index| Accounts::Player.create!(steam_id: "7656119796028800#{index}", persona_name: "Friend #{index}") }
    @players += friends
    @created = friends
    friends.each { |friend| befriend(@alice, friend) }
    hold(@alice, @card, 3)

    results = together(*friends.map { |friend| propose(@alice, friend, { @card => 1 }, { @other => 1 }) })

    assert_equal 3, results.count(&:success?)
    assert_equal [ :insufficient_copies ] * 2, results.select(&:failure?).map(&:failure)
    assert_equal 3, reserved(@alice, @card)
    assert_equal 3, Game::Trade.in_progress.count
  end

  test "opposite proposals of a pair at once: one opens the trade, the other is refused, no deadlock" do
    befriend(@alice, @bob)
    hold(@alice, @card, 1)
    hold(@bob, @other, 1)

    results = together(propose(@alice, @bob, { @card => 1 }, { @other => 1 }), propose(@bob, @alice, { @other => 1 }, { @card => 1 }))

    assert_equal 1, results.count(&:success?)
    assert_equal [ :trade_already_open ], results.select(&:failure?).map(&:failure)
    assert_equal 1, Game::Trade.count
  end

  test "crossing trades around three players, repeated, never deadlock and each reserves its own offer" do
    befriend(@alice, @bob)
    befriend(@bob, @carol)
    befriend(@alice, @carol)
    [ @alice, @bob, @carol ].each do |player|
      hold(player, @card, 1)
      hold(player, @other, 1)
    end
    pairs = [ [ @alice, @bob ], [ @bob, @carol ], [ @carol, @alice ] ]

    8.times do
      results = together(*pairs.map { |from, to| propose(from, to, { @other => 1, @card => 1 }, { @card => 1 }) })

      assert results.all?(&:success?), results.inspect
      assert_equal [ 1, 1, 1 ], @players.map { |player| reserved(player, @card) }
      cancels = together(*Game::Trade.uncached { Game::Trade.in_progress.to_a }.map { |trade| -> { Game::CancelTrade.new.call(player: Accounts::Player.find(trade.proposer_id), trade_id: trade.id) } })
      assert cancels.all?(&:success?), cancels.inspect
      assert_equal [ 0, 0, 0 ], @players.map { |player| reserved(player, @card) }
    end
  end

  test "a cancel and a decline racing on one trade: exactly one closes it and releases once" do
    befriend(@alice, @bob)
    hold(@alice, @card, 2)
    trade = propose(@alice, @bob, { @card => 2 }, { @other => 1 }).call.value!

    results = together(
      -> { Game::CancelTrade.new.call(player: Accounts::Player.find(@alice.id), trade_id: trade.id) },
      -> { Game::DeclineTrade.new.call(player: Accounts::Player.find(@bob.id), trade_id: trade.id) }
    )

    assert_equal 1, results.count(&:success?)
    assert_equal [ :trade_not_open ], results.select(&:failure?).map(&:failure)
    assert_equal 0, reserved(@alice, @card)
    assert_not trade.reload.open?
  end

  test "a proposal racing a cancel of the previous trade never reserves beyond owned" do
    befriend(@alice, @bob)
    befriend(@alice, @carol)
    hold(@alice, @card, 2)
    trade = propose(@alice, @bob, { @card => 2 }, { @other => 1 }).call.value!

    together(
      -> { Game::CancelTrade.new.call(player: Accounts::Player.find(@alice.id), trade_id: trade.id) },
      propose(@alice, @carol, { @card => 2 }, { @other => 1 })
    )

    assert_includes [ 0, 2 ], reserved(@alice, @card)
    assert_equal reserved(@alice, @card), Game::Trade.in_progress.where(proposer_id: @alice.id).count * 2
  end
end
