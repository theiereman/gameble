require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/rake_tasks"

class Game::GrantCardBackJobTest < ActiveSupport::TestCase
  include GamePacks
  include RakeTasks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def unlocked(player) = Game::CardBackUnlock.where(player_id: player.id).pluck(:back)
  def grant(back, *steam_ids) = Game::GrantCardBackJob.grant(back:, steam_ids:)

  def run_task(*args)
    rake_task("game:grant_card_back").execute(Rake::TaskArguments.new(%i[back steam_ids], args))
  end

  test "a group is granted the event back, one unlock event each" do
    outcome = grant("saison-1", @player.steam_id, @other.steam_id)

    assert_equal [ 2, 0, 0, 0 ], outcome.to_h.values
    assert_equal [ "saison-1" ], unlocked(@player)
    assert_equal [ "saison-1" ], unlocked(@other)
    assert_equal 1, game_events(@player, Game::CardBackUnlocked).size
  end

  test "run twice it grants only what is missing" do
    grant("millesime-2017", @player.steam_id)
    outcome = grant("millesime-2017", @player.steam_id, @other.steam_id)

    assert_equal [ 1, 1, 0, 0 ], outcome.to_h.values
    assert_equal 1, Game::CardBackUnlock.where(player_id: @player.id).count
  end

  test "an unknown Steam id and a banned player are counted, not granted" do
    @other.update!(banned_at: Time.current)

    outcome = grant("soldes-hiver", "76561190000000000", @other.steam_id, @player.steam_id)

    assert_equal 1, outcome.granted
    assert_equal 2, outcome.not_found
    assert_empty unlocked(@other)
  end

  test "one failure does not roll back the others" do
    failing_id = @player.id
    record = Game::CardBackUnlock.method(:record)
    Game::CardBackUnlock.define_singleton_method(:record) { |player_id, back, now| player_id == failing_id ? raise("boom") : record.call(player_id, back, now) }

    outcome = grant("saison-1", @player.steam_id, @other.steam_id)

    assert_equal [ 1, 0, 0, 1 ], outcome.to_h.values
    assert_empty unlocked(@player)
    assert_equal [ "saison-1" ], unlocked(@other)
  ensure
    Game::CardBackUnlock.define_singleton_method(:record, record)
  end

  test "the rake task grants the group and says so" do
    output, = capture_io { run_task("saison-1", "#{@player.steam_id} #{@other.steam_id}") }

    assert_equal [ "saison-1" ], unlocked(@player)
    assert_match "2 granted", output
  end

  test "the rake task refuses a back that is not an event back" do
    error = nil
    capture_io { error = assert_raises(SystemExit) { run_task("aurore", @player.steam_id) } }

    assert_equal 1, error.status
    assert_empty unlocked(@player)
  end
end
