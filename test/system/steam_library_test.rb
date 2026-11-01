require "application_system_test_case"
require_relative "../support/game_sets"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"

# A player signed in with Steam gets their Steam library set with no action
# of theirs: the daily sync fills it from the games Steam lists, the
# collection shows it under MA LUDOTHÈQUE STEAM once synced, and a library
# Steam stops sharing keeps its games under a quiet line.
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

  def steam_shares_nothing = @owned = {}

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

  def today = I18n.l(Date.current, format: Date.current.day == 1 ? :long_day_first : :long_day, locale: :en)

  test "signing in with Steam makes the library set; once synced the collection shows it, and a later sync adds a new game to its album" do
    hold_all(@player, [ catalog_card_seasons(:portal_one).id ])
    steam_lists(:portal, :common_card)
    sign_in_with_steam
    visit library_path(locale: :en)
    assert_selector "section.custom-sets"
    assert_no_selector "section.steam-library"

    run_daily_sync
    visit library_path(locale: :en)

    within("section.steam-library") do
      assert_selector "h2", text: "MY STEAM LIBRARY"
      assert_text "Synced with Steam on #{today}."
      assert_link class: "steam-library__link", text: /My Steam library/
      assert_selector ".steam-library__kind", text: "STEAM · 2 CATALOG GAMES"
      assert_selector ".custom-sets__count", text: "1/2"
    end

    sign_out
    assert_signed_out
    sign_in_with_steam
    assert_equal 1, Game::CustomSet.steam_library.where(player_id: @player.id).count

    steam_lists(:portal, :common_card, :rare_card)
    run_daily_sync
    visit library_path(locale: :en)
    click_on "My Steam library"

    assert_selector "h1#set-album-heading", text: "MY STEAM LIBRARY"
    assert_selector ".set-album__count", text: "1/3"
    assert_selector ".set-album__grid .card", count: 3
    assert_no_link "Edit"
    assert_no_button "Delete"
  end

  test "a library Steam stops sharing keeps its games under the not-shared line with the last sync, and a typed search hides the section" do
    steam_lists(:portal, :common_card)
    sign_in_with_steam
    run_daily_sync

    steam_shares_nothing
    run_daily_sync
    visit library_path(locale: :en)

    within("section.steam-library") do
      assert_text "Steam does not share your library. Make the game details of your Steam profile public."
      assert_selector "b", text: "Last sync: #{today}."
      assert_selector ".custom-sets__count", text: "0/2"
    end

    fill_in "set-search-field", with: "zzz"
    assert_selector ".set-results"
    assert_no_selector "section.steam-library", visible: true
  end
end
