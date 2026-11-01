require "test_helper"
require_relative "../support/game_packs"

# The library set made after a Steam sign-in: once per player, never a Steam
# call, never a sync of its own.
class CreateSteamLibrarySetJobTest < ActiveJob::TestCase
  include GamePacks

  setup { @player = accounts_players(:player) }

  test "it runs on the default queue" do
    assert_equal "default", CreateSteamLibrarySetJob.new.queue_name
  end

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
end
