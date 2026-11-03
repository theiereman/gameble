require "test_helper"
require_relative "../support/game_packs"

# The library set made after a Steam sign-in: once per player, never a Steam
# call, never a sync of its own.
class CreateSteamLibrarySetJobTest < ActiveJob::TestCase
  include GamePacks

  setup { @player = accounts_players(:player) }

  test "it creates the player's one library set, without a Steam call or a sync" do
    assert_no_enqueued_jobs do
      2.times { CreateSteamLibrarySetJob.perform_now(@player.id) }
    end

    assert_equal 1, Game::CustomSet.steam_library.where(player_id: @player.id).count
    assert_equal 1, game_events(@player, Game::LibrarySetCreated).size
  end

  test "a player without a Steam identity, banned or gone gets no set" do
    @player.identities.where(provider: "steam").delete_all

    [ @player.id, accounts_players(:banned).id, -1 ].each { CreateSteamLibrarySetJob.perform_now(it) }

    assert_not Game::CustomSet.steam_library.exists?
  end

  test "a first sync, asked when the player turns the sync back on, enqueues one sync of the new set" do
    assert_enqueued_jobs 1, only: SyncSteamLibraryJob do
      CreateSteamLibrarySetJob.perform_now(@player.id, first_sync: true)
    end

    library_set = Game::CustomSet.steam_library.find_by!(player_id: @player.id)
    assert_enqueued_with job: SyncSteamLibraryJob, args: [ @player.id, library_set.token ]
  end

  test "a player who turned the sync off gets no set, no event and no sync" do
    @player.update_column(:steam_library_sync, false)

    assert_no_enqueued_jobs do
      CreateSteamLibrarySetJob.perform_now(@player.id)
      CreateSteamLibrarySetJob.perform_now(@player.id, first_sync: true)
    end

    assert_not Game::CustomSet.steam_library.exists?
    assert_empty game_events(@player, Game::LibrarySetCreated)
  end
end
