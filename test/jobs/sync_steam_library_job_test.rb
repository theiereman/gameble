require "test_helper"
require_relative "../support/steam_api_stubs"
require_relative "../support/custom_sets"

# One player's Steam library set synced from Steam, on the queue the import
# worker serves: one Steam call, the published games it lists, the set kept
# when Steam does not share the library or does not answer.
class SyncSteamLibraryJobTest < ActiveJob::TestCase
  include SteamApiStubs
  include CustomSets

  PORTAL_APPID, RARE_APPID, UNKNOWN_APPID = 400, 403, 999

  setup do
    stub_steam_api
    @player = accounts_players(:player)
    catalog_cards(:portal).update_column(:source_key, Steam::CardMapping.source_key(PORTAL_APPID))
    catalog_cards(:rare_card).update_column(:source_key, Steam::CardMapping.source_key(RARE_APPID))
    @library_set = create_library_set(@player, card_ids: [ catalog_cards(:common_card).id ], synced_at: 2.days.ago)
  end

  teardown { unstub_steam_api }

  def perform(player_id: @player.id, token: @library_set.token) = SyncSteamLibraryJob.perform_now(player_id, token)

  def games = Game::CustomSetGame.where(custom_set_id: @library_set.id).order(:card_id).pluck(:card_id)

  test "it runs on the steam_library queue" do
    assert_equal "steam_library", SyncSteamLibraryJob.new.queue_name
  end

  test "a public library replaces the set's games by the catalog games Steam lists, in one call for the player's Steam id" do
    calls = stub_owned_games([ RARE_APPID, UNKNOWN_APPID, PORTAL_APPID ])

    perform

    assert_equal [ catalog_cards(:portal).id, catalog_cards(:rare_card).id ].sort, games
    assert_in_delta Time.current, @library_set.reload.synced_at, 5
    assert_equal [ "76561197960287001" ], calls.map { it["steamid"] }
  end

  test "a private library keeps the games and the last sync and records since when" do
    synced_at = @library_set.synced_at
    stub_private_owned_games(game_count: 12)

    perform

    @library_set.reload
    assert_equal [ [ catalog_cards(:common_card).id ], synced_at.to_i ], [ games, @library_set.synced_at.to_i ]
    assert @library_set.library_private_since
  end

  test "Steam unavailable leaves the set and its sync state as they were" do
    stub_owned_games_failure(503)

    assert_no_changes -> { [ games, @library_set.reload.attributes ] } do
      perform
    end
  end

  test "a rejected key raises out of the job and writes nothing" do
    stub_owned_games_failure(403)

    assert_no_changes -> { @library_set.reload.attributes } do
      assert_raises(Steam::WebApi::BrokenKey) { perform }
    end
  end

  test "no Steam call for a missing, banned or deleted player, nor for a player without a Steam identity" do
    calls = stub_owned_games([ PORTAL_APPID ])
    banned = accounts_players(:banned)
    deleted = accounts_players(:moderator).tap { it.update_columns(deleted_at: Time.current, steam_id: nil) }

    [ -1, banned.id, deleted.id ].each { perform(player_id: it) }
    @player.identities.where(provider: "steam").delete_all
    perform

    assert_empty calls
    assert_equal [ catalog_cards(:common_card).id ], games
  end

  test "a set gone since the day's selection is not created again" do
    stub_owned_games([ PORTAL_APPID ])
    Game::CustomSet.where(id: @library_set.id).delete_all

    perform

    assert_not Game::CustomSet.steam_library.exists?(player_id: @player.id)
  end
end
