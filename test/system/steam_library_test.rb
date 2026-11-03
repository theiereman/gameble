require "application_system_test_case"
require_relative "../support/game_sets"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"

# Turning the Steam library sync off in the settings asks first, and a
# confirmation erases the set.
class SteamLibraryTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include GameSets
  include SteamApiStubs
  include SteamSignIn

  APPIDS = { portal: 400, common_card: 401, rare_card: 403 }.freeze

  setup do
    stub_steam_api
    @player = accounts_players(:player)
    stub_player_summary(@player.steam_id, "Gabe")
    APPIDS.each { |card, appid| catalog_cards(card).update_column(:source_key, Steam::CardMapping.source_key(appid)) }
    @owned = nil
    steam_stubs.get(SteamApiStubs::OWNED_GAMES_PATH) do
      [ 200, { "Content-Type" => "application/json" }, { "response" => @owned }.to_json ]
    end
  end

  teardown { unstub_steam_api }

  def steam_lists(*cards)
    @owned = { "game_count" => cards.size, "games" => cards.map { { "appid" => APPIDS.fetch(it), "playtime_forever" => 60 } } }
  end

  def sign_in_with_steam
    mock_steam_sign_in(@player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    perform_enqueued_jobs(only: CreateSteamLibrarySetJob)
  end

  def run_daily_sync
    perform_enqueued_jobs(only: SyncSteamLibraryJob) { SyncSteamLibrariesJob.perform_now }
  end

  test "turning the sync off asks first, and a confirmation erases the set" do
    steam_lists(:portal, :common_card)
    sign_in_with_steam
    run_daily_sync
    library_set = Game::CustomSet.steam_library.find_by!(player_id: @player.id)
    visit settings_path(locale: :fr)

    within("[role=group][aria-labelledby=settings-steam-library]") { click_on "Non" }
    within("dialog#library-sync-dialog[open]") do
      assert_selector "#library-sync-dialog-title", text: "DÉSACTIVER LA SYNCHRONISATION\u202F?"
      assert_text "Le set MA BIBLIOTHÈQUE STEAM et la liste de vos jeux Steam seront effacés."
      click_on "Annuler"
    end
    assert_no_selector "dialog#library-sync-dialog[open]"
    assert @player.reload.steam_library_sync
    assert Game::CustomSet.exists?(library_set.id)

    within("[role=group][aria-labelledby=settings-steam-library]") { click_on "Non" }
    within("dialog#library-sync-dialog[open]") { click_on "Désactiver" }
    assert_selector "button[name=steam_library_sync][value=off][aria-pressed=true]"
    assert_no_selector "dialog#library-sync-dialog"
    assert_not @player.reload.steam_library_sync
    assert_not Game::CustomSet.exists?(library_set.id)
    assert_equal 0, Game::CustomSetGame.where(custom_set_id: library_set.id).count
  end
end
