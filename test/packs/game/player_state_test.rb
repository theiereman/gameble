require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/rake_tasks"

class Game::PlayerStateTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    Game::DrawPool.reset!
    @player = accounts_players(:player)
  end

  def create(player) = Game::CreatePlayerState.new.call(player:)
  def states = Game::PlayerState.where(player_id: @player.id)

  test "every fixture player has their row" do
    assert_equal accounts_players.map(&:id).sort, Game::PlayerState.pluck(:player_id).sort
  end

  test "a player without a row gets one; a rerun keeps it and publishes nothing" do
    states.delete_all

    state = create(@player).value!

    assert_equal states.sole, state
    assert_equal @player.id, state.player_id
    assert_equal state, create(@player).value!
    assert_equal 1, states.count
    assert_empty game_events(@player)
  end

  test "a banned player gets a row too; a missing or unsaved player fails with player_required" do
    banned = accounts_players(:banned)
    Game::PlayerState.where(player_id: banned.id).delete_all

    assert create(banned).success?
    assert Game::PlayerState.exists?(player_id: banned.id)
    [ nil, Accounts::Player.new(steam_id: "76561197960287888") ].each do |player|
      assert_equal :player_required, create(player).failure
    end
  end

  test "the database keeps one row per player" do
    assert_raises(ActiveRecord::RecordNotUnique) { Game::PlayerState.create!(player_id: @player.id) }
  end

  test "a player deleted since their row was read fails player_required and keeps no row" do
    deleted = @player
    Accounts::DeletePlayer.new.call(player: Accounts::Player.find(deleted.id)).value!

    assert_equal Dry::Monads::Failure(:player_required), create(deleted)
    assert_not Game::PlayerState.exists?(player_id: deleted.id)
  end

  test "the sign-up handler creates the new player's row after their bank" do
    player = Accounts::Player.create!(steam_id: "76561197960287889")

    Game::Handlers::PlayerRegistered.call(Accounts::PlayerRegistered.new(data: { player_id: player.id }))

    assert Game::PlayerState.exists?(player_id: player.id)
    assert_equal 10, Game::Pack.bank(player.id).count
  end

  test "a player signing up gets their row in the sign-up's transaction" do
    player = Accounts::SignIn.new.call(steam_id: "76561197960287890", persona_name: nil).value!

    assert Game::PlayerState.exists?(player_id: player.id)
  end
end

class Game::BackfillPlayerStatesJobTest < ActiveSupport::TestCase
  include RakeTasks

  setup { rake_task("game:backfill_player_states") }

  test "every player without a row gets one, banned included; those with a row cost nothing; a rerun is a no-op" do
    Game::PlayerState.where(player_id: [ accounts_players(:player).id, accounts_players(:banned).id ]).delete_all
    newcomer = Accounts::Player.create!(steam_id: "76561197960287891")
    kept = Game::PlayerState.find_by!(player_id: accounts_players(:moderator).id)

    Game::BackfillPlayerStatesJob.perform_now

    players = Accounts::Player.pluck(:id).sort
    assert_equal players, Game::PlayerState.pluck(:player_id).sort
    assert Game::PlayerState.exists?(player_id: newcomer.id)
    assert_equal kept, Game::PlayerState.find_by!(player_id: accounts_players(:moderator).id)

    assert_no_difference -> { Game::PlayerState.count } do
      # The batch of players, then which of them have a row.
      assert_queries_count(2) { Game::BackfillPlayerStatesJob.perform_now }
    end
  end

  # Game::CreatePlayerState raises for the player of `failing_id` while the
  # block runs, and creates the others' rows.
  def failing_for(failing_id)
    create = Game::CreatePlayerState.new
    Game::CreatePlayerState.define_singleton_method(:new) do
      Object.new.tap do |operation|
        operation.define_singleton_method(:call) do |player:|
          raise "the state row failed" if player.id == failing_id

          create.call(player:)
        end
      end
    end
    yield
  ensure
    Game::CreatePlayerState.singleton_class.remove_method(:new)
  end

  def run_task
    rake_task("game:backfill_player_states").execute
  end

  test "a player whose creation raises is reported and skipped; the others still get their row" do
    Game::PlayerState.delete_all
    failing_id = accounts_players(:player).id

    failing_for(failing_id) do
      assert_error_reported(RuntimeError) { Game::BackfillPlayerStatesJob.perform_now }
    end

    assert_not Game::PlayerState.exists?(player_id: failing_id)
    assert_equal accounts_players.map(&:id).sort - [ failing_id ], Game::PlayerState.pluck(:player_id).sort
    assert_equal 1, Game::BackfillPlayerStatesJob.players_without_a_row
  end

  test "the rake task runs the job and says every player has their row" do
    Game::PlayerState.where(player_id: accounts_players(:player).id).delete_all

    output, = capture_io { run_task }

    assert Game::PlayerState.exists?(player_id: accounts_players(:player).id)
    assert_match "every player has their game_player_states row", output
  end

  test "the rake task fails, naming how many players are still without a row" do
    Game::PlayerState.delete_all

    error = nil
    failing_for(accounts_players(:player).id) do
      assert_error_reported(RuntimeError) do
        error = assert_raises(SystemExit) { capture_io { run_task } }
      end
    end

    assert_not error.success?
    assert_match "1 player(s) still without a game_player_states row", error.message
  end
end
