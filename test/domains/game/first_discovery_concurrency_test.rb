require "test_helper"
require_relative "../../support/game_packs"

# First discoveries under concurrency: two players
# open packs holding the same undiscovered card at once; the unique index
# makes the second insert wait for the first to commit, then skip, so the
# card is recorded and published once and both openings succeed. Each thread
# has its own connection, so the test commits for real and cleans up after
# itself, the fixture's discovery row put back.
class Game::FirstDiscoveryConcurrencyTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  setup do
    @players = [ accounts_players(:player), accounts_players(:moderator) ]
    @card = catalog_card_seasons(:legendary_card_one).id
    @fixture_row = Game::FirstDiscovery.find_by!(card_season_id: @card).attributes
    Game::FirstDiscovery.where(card_season_id: @card).delete_all
  end

  teardown do
    ids = @players.map(&:id)
    Game::FirstDiscovery.where(player_id: ids).delete_all
    Game::FirstDiscovery.insert_all!([ @fixture_row ]) unless Game::FirstDiscovery.exists?(card_season_id: @card)
    Game::Holding.where(player_id: ids).delete_all
    Game::FeedEntry.where(player_id: ids).delete_all
    Game::WeeklyContribution.where(player_id: ids).delete_all
    Game::SetTier.where(player_id: ids).delete_all
    Game::Pack.where(player_id: ids).delete_all
    streams = ids.map { |id| Game::Operation.stream_name(id) }
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  # Both players open their pack together, each on its own connection. A
  # deadlock would hang the threads: a timeout fails the test instead.
  def open_together
    gate = Queue.new
    threads = @players.map do |player|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          Game::OpenPack.new.call(player: Accounts::Player.find(player.id))
        end
      end
    end
    @players.size.times { gate << :go }
    threads.map { |thread| thread.join(20) ? thread.value : flunk("a thread is stuck: deadlock") }
  end

  test "two players pulling the same new card at once: one discovery, one event, both openings succeed" do
    common = catalog_card_seasons(:common_card_one).id
    @players.each { |player| create_pack(player, cards: [ common, @card, common, @card, common ]) }

    results = open_together

    assert results.all?(&:success?)
    discovery = Game::FirstDiscovery.where(card_season_id: @card).sole
    winner = results.map(&:value!).find { |pack| pack.id == discovery.pack_id }
    assert_equal winner.player_id, discovery.player_id
    events = @players.flat_map { |player| game_events(player, Game::CardDiscovered) }
    assert_equal [ { player_id: winner.player_id, card_season_id: @card, pack_id: winner.id } ], events.map(&:data)
    kinds = Game::FeedEntry.where(card_season_id: @card).order(:pack_id, :position).pluck(:pack_id, :kind)
    assert_equal 1, kinds.count { |_, kind| kind == "discovery" }
    assert_equal [ [ winner.id, "discovery" ] ], kinds.select { |_, kind| kind == "discovery" }
    assert_equal [ 5, 5 ], @players.map { |player| Game::Holding.where(player_id: player.id).sum(:quantity) }
  end
end
