require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/running_release"

# Every note players were shown, newest first, each drawn as the hub's dialog draws it.
class ReleaseNotesHistoryTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include RunningRelease

  setup do
    @player = accounts_players(:player)
  end

  test "the notes of the running release, each headed by its version alone, and the ones before it, newest first, in the player's language" do
    older = write_release_note("v1.2.0", title_en: "Trades arrive")
    newer = write_release_note("v1.3.0")
    write_release_note("v1.4.0")
    write_release_note("v1.2.5", state: "draft")
    write_release_note("v1.2.6", state: "skipped")
    run_release("v1.3.0")
    sign_in(@player)

    get release_notes_path(locale: :en)

    assert_response :success
    assert_select "title", /Release notes/
    assert_select "h1.visually-hidden", "Release notes"
    assert_select ".release-note-log.page.page--reading ol.release-note-log__list > li", 2
    assert_equal [ "v1.3.0", "v1.2.0" ], css_select(".release-note-kicker__version").map(&:text)
    assert_select "article.panel--brackets[aria-labelledby='release-note-#{newer.token}']" do
      assert_select ".release-note-kicker", "v1.3.0"
      assert_select "h2#release-note-#{newer.token}.release-note__title", "Capsules open at once"
      assert_select ".release-note__item", "Capsules open at once"
    end
    assert_select "h2#release-note-#{older.token}", "Trades arrive"
    assert_select ".release-note-log [style]", 0
    assert_select "a[href='/en']", minimum: 1
  end

  test "French reads the French notes" do
    write_release_note("v1.3.0")
    run_release("v1.3.0")
    sign_in(@player)

    get release_notes_path(locale: :fr)

    assert_select ".release-note-kicker", "v1.3.0"
    assert_select ".release-note__title", "Les capsules s'ouvrent d'un coup"
  end

  test "one quiet line while no note was shown yet" do
    write_release_note("v1.4.0")
    run_release("v1.3.0")
    sign_in(@player)

    get release_notes_path(locale: :fr)

    assert_select ".release-note-log__list", 0
    assert_select "p.release-note-log__empty", "Aucune note de version pour l'instant."
  end

  test "a visitor is sent to the landing" do
    get release_notes_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
  end

  test "the settings link to the release notes" do
    sign_in(@player)

    get settings_path(locale: :fr)

    assert_select ".settings-row a[href='/fr/release-notes']", "Notes de version"
  end
end
