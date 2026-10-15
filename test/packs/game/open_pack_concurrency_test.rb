require "test_helper"
require_relative "../../support/game_packs"

# Game::OpenPack under concurrency (AD-7): the bank lock serialises two
# openings by the same player. Each thread has its own connection, so the
# test commits for real and cleans up after itself.
class Game::OpenPackConcurrencyTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  setup { @player = accounts_players(:player) }

  teardown do
    Game::Holding.where(player_id: @player.id).delete_all
    Game::FeedEntry.where(player_id: @player.id).delete_all
    Game::WeeklyContribution.where(player_id: @player.id).delete_all
    Game::SetTier.where(player_id: @player.id).delete_all
    Game::FirstDiscovery.where(player_id: @player.id).delete_all
    Game::Pack.where(player_id: @player.id).delete_all
    stream = Game::Operation.stream_name(@player.id)
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  # Two openings started together, each on its own connection.
  def open_twice(idempotency_key: nil)
    gate = Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          Game::OpenPack.new.call(player: Accounts::Player.find(@player.id), idempotency_key:)
        end
      end
    end
    2.times { gate << :go }
    threads.map(&:value)
  end

  test "two openings at once both succeed, on different packs" do
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }

    results = open_twice

    assert results.all?(&:success?)
    assert_equal 2, results.map { |result| result.value!.id }.uniq.size
    assert_equal 1, Game::BankSummary.call(@player)[:available]
    assert_equal [ 10 ], Game::Holding.where(player_id: @player.id).pluck(:quantity)
  end

  test "two openings of a full bank at once: replacements ten and twenty minutes after the opening" do
    now = Time.current.change(usec: 0)
    10.times { |index| create_pack(@player, available_at: now - (index + 1).minutes) }

    results = travel_to(now) { open_twice }

    assert results.all?(&:success?)
    bank = Game::Pack.bank(@player.id)
    assert_equal 10, bank.count
    assert_equal [ now + 10.minutes, now + 20.minutes ], bank.where(available_at: now..).order(:available_at).pluck(:available_at)
  end

  test "two openings racing on the last pack: one succeeds, the other is refused" do
    create_pack(@player)

    results = open_twice

    assert_equal 1, results.count(&:success?)
    assert_equal [ :no_pack_available ], results.select(&:failure?).map(&:failure)
    assert_equal [ 5 ], Game::Holding.where(player_id: @player.id).pluck(:quantity)
  end

  test "two openings at once with one key: one pack opened, both answer it" do
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }

    results = open_twice(idempotency_key: SecureRandom.uuid)

    assert results.all?(&:success?)
    assert_equal 1, results.map { |result| result.value!.id }.uniq.size
    assert_equal 1, Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).count
    assert_equal 2, Game::BankSummary.call(@player)[:available]
    assert_equal [ 5 ], Game::Holding.where(player_id: @player.id).pluck(:quantity)
    assert_equal 1, Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@player.id)).of_type(Game::PackOpened).count
  end
end
