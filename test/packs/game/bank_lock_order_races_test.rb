require "test_helper"
require_relative "../../support/game_packs"

# Bank operations of several players raced against each other: the
# publication's healing (Game::HealBanksJob), openings, a daily bonus, a
# trade's acceptance and an account deletion. An operation that locks
# several players takes their bank locks in ascending player id, then their
# holdings in ascending player and card-season, then their game state rows,
# so no two of them wait on each other. A deadlock Postgres detects raises
# ActiveRecord::Deadlocked from its thread, which fails the test; a thread
# that never returns fails it too. The draw pool is slowed, as in
# Game::BankRacesTest, to widen the window between reading a bank and
# writing it. Each thread has its own connection, so the test commits for
# real; it uses players of its own and removes every row it made.
class Game::BankLockOrderRacesTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  # How long each read of the draw pool waits.
  POOL_DELAY = 0.15

  setup do
    Game::DrawPool.reset!
    @first, @second, @third = %w[76561197960310001 76561197960310002 76561197960310003].each_with_index.map do |steam_id, index|
      Accounts::Player.create!(steam_id:, persona_name: "Racer #{index + 1}")
    end
    @created = [ @first, @second, @third ]
    @rare = catalog_card_seasons(:rare_card_one).id
    @uncommon = catalog_card_seasons(:uncommon_card_one).id
    @portal = catalog_card_seasons(:portal_one).id
    @current = Game::DrawPool.method(:current)
    current = @current
    Game::DrawPool.define_singleton_method(:current) do
      sleep POOL_DELAY
      current.call
    end
  end

  teardown do
    Game::DrawPool.define_singleton_method(:current, @current)
    players = Accounts::Player.pluck(:id)
    created = @created.map(&:id)
    trades = Game::Trade.where(proposer_id: created).or(Game::Trade.where(recipient_id: created))
    Game::TradeItem.where(trade_id: trades.select(:id)).delete_all
    trades.delete_all
    Game::Friendship.where(low_player_id: created).or(Game::Friendship.where(high_player_id: created)).delete_all
    Game::FirstDiscovery.where(pack_id: Game::Pack.where(player_id: players).select(:id)).delete_all
    [ Game::DailyBonusClaim, Game::GoalReward, Game::Holding, Game::FeedEntry, Game::WeeklyContribution, Game::SetCompletion,
      Game::Pack ].each { |model| model.where(player_id: players).delete_all }
    [ Game::PlayerState, Game::FriendCode ].each { |model| model.where(player_id: created).delete_all }
    streams = players.map { |id| Game::Operation.stream_name(id) } + created.map { |id| "Accounts::Player$#{id}" }
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Accounts::Player.where(id: created).delete_all
  end

  # Runs the blocks at once, each on its own connection, and returns their
  # results in order; a thread that never returns fails the test.
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

  def open(player) = -> { Game::OpenPack.new.call(player: Accounts::Player.find(player.id)) }
  def bonus(player) = -> { Game::CollectDailyBonus.new.call(player: Accounts::Player.find(player.id)) }
  def accept(player, trade) = -> { Game::AcceptTrade.new.call(player: Accounts::Player.find(player.id), trade_id: trade.id) }
  def delete(player) = -> { Accounts::DeletePlayer.new.call(player: Accounts::Player.find(player.id)) }

  # The job reports a player's failure and goes on: a deadlock it swallowed
  # fails the test here.
  def publication_job = -> { assert_no_error_reported { Game::HealBanksJob.perform_now } }

  def bank(player) = Game::Pack.bank(player.id)
  def topped_up(player) = game_events(player, Game::BankToppedUp).map { |event| event.data[:packs] }
  def filled(player) = game_events(player, Game::BankFilled).size
  def quantity(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)&.quantity.to_i

  # Two friends, each with one available pack of five portal cards, and an
  # open trade: the higher id offers a rare card for the lower id's
  # uncommon one, so the acceptance and a deletion lock the recipient's bank
  # first.
  def offered_trade
    Game::Friendship.create!(low_player_id: @first.id, high_player_id: @second.id)
    Game::Holding.create!(player_id: @second.id, card_season_id: @rare, quantity: 2)
    Game::Holding.create!(player_id: @first.id, card_season_id: @uncommon, quantity: 2)
    [ @first, @second ].each { |player| create_pack(player) }
    Game::ProposeTrade.new.call(player: @second, recipient: @first, offer: { @rare => 1 }, request: { @uncommon => 1 }).value!
  end

  test "the publication's job while two players open and a third collects a bonus: every bank healed once to ten" do
    3.times { |index| create_pack(@first, available_at: (index + 1).minutes.ago) }
    open_unpublished(@first, 2)
    3.times { |index| create_pack(@third, available_at: (index + 1).minutes.from_now) }

    _, short, empty, collected = together(publication_job, open(@first), open(@second), bonus(@third))

    assert_predicate short, :success?
    # The second player never had a pack: before the job fills the bank,
    # there is nothing to open.
    assert empty.success? || empty.failure == :no_pack_available, empty.inspect
    # Scheduled packs and seven healed ones: the reserve is never full.
    assert_predicate collected, :success?
    @created.each { |player| assert_equal 10, bank(player).count }
    assert_equal 1, Game::Pack.where(player_id: @third.id).bonus.unopened.count
    assert_equal [ [ 9 ], [], [ 7 ] ], @created.map { |player| topped_up(player) }
    assert_equal [ 0, 1, 0 ], @created.map { |player| filled(player) }
    %i[player moderator administrator].each { |name| assert_equal 10, bank(accounts_players(name)).count, name }
    [ @first, @second ].each { |player| assert_spent_once(player) }
  end

  test "a trade's acceptance while both partners open a pack: the cards swap once, both openings credited" do
    trade = offered_trade

    accepted, *openings = together(accept(@first, trade), open(@first), open(@second))

    assert_predicate accepted, :success?
    assert openings.all?(&:success?), openings.inspect
    assert_equal [ 1, 1, 5 ], [ quantity(@first, @rare), quantity(@first, @uncommon), quantity(@first, @portal) ]
    assert_equal [ 1, 1, 5 ], [ quantity(@second, @rare), quantity(@second, @uncommon), quantity(@second, @portal) ]
    assert_equal 0, Game::Holding.where(player_id: [ @first.id, @second.id ]).sum(:reserved)
    assert_equal "accepted", trade.reload.status
    [ @first, @second ].each { |player| assert_opened_once(player) }
  end

  test "a partner's deletion while the other opens a pack and accepts their trade: no row of the deleted player, nothing reserved" do
    trade = offered_trade

    deletion, opening, accepted = together(delete(@second), open(@first), accept(@first, trade))

    assert_predicate deletion, :success?
    assert_predicate opening, :success?
    # Accepted before the deletion commits, or found cancelled by it.
    assert accepted.success? || accepted.failure == :trade_not_open, accepted.inspect
    trade.reload
    assert_equal accepted.success? ? "accepted" : "cancelled", trade.status
    left = [ Game::Pack, Game::Holding, Game::FeedEntry, Game::DailyBonusClaim, Game::GoalReward, Game::SetCompletion, Game::PlayerState,
      Game::FriendCode ].to_h { |model| [ model.name, model.where(player_id: @second.id).count ] }
    assert_equal left.transform_values { 0 }, left
    assert_equal 0, Game::Friendship.of(@second.id).count
    assert_equal 0, Game::Holding.where(player_id: @first.id).sum(:reserved)
    swapped = accepted.success? ? 1 : 0
    assert_equal [ swapped, 2 - swapped, 5 ], [ quantity(@first, @rare), quantity(@first, @uncommon), quantity(@first, @portal) ]
    assert_opened_once(@first)
  end
end
