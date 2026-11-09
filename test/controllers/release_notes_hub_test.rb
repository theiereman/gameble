require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/running_release"

# The notes of the running release: a dialog over the hub on the web, a native
# sheet in the app, shown once to each player; a reminder for administrators
# while production runs a release without a note.
class ReleaseNotesHubTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include RunningRelease
  include ActiveJob::TestHelper

  APP = "Gameble Android; Hotwire Native Android; Turbo Native Android; bridge-components: [sign-in share haptics]".freeze

  setup do
    @player = accounts_players(:player)
  end

  test "the hub opens the running release's note once, in the player's language" do
    note = write_release_note("v1.3.0")
    run_release("v1.3.0")
    sign_in(@player, origin: "/fr")

    assert_enqueued_with(job: Accounts::SeeReleaseNoteJob, args: [ @player.id, note.id ]) { get home_path(locale: :fr) }

    assert_select "dialog#release-note-dialog.modal[aria-labelledby=release-note-title][data-controller=welcome]" do
      assert_select ".release-note-kicker", /Mise à jour installée · v1.3.0/
      assert_select "h2#release-note-title", "Les capsules s'ouvrent d'un coup"
      assert_select ".release-note__section-title", "Nouveautés"
      assert_select ".release-note__item", "Les capsules s'ouvrent d'un coup"
      assert_select "button.button--primary[data-action='welcome#close']", "Compris"
    end
    assert_select "#release-note-dialog [style]", 0

    perform_enqueued_jobs
    assert_no_enqueued_jobs(only: Accounts::SeeReleaseNoteJob) { get home_path(locale: :fr) }
    assert_select "#release-note-dialog", 0
  end

  test "a candidate, a draft or a pending welcome shows no note" do
    write_release_note("v1.3.0")
    write_release_note("v1.4.0", state: "draft")
    sign_in(@player)

    [ "v1.3.0-rc.2", "v1.2.9" ].each do |version|
      run_release(version)
      get home_path(locale: :en)
      assert_select "#release-note-dialog", 0
    end

    run_release("v1.4.0")
    get home_path(locale: :en)
    assert_select "h2#release-note-title", "Capsules open at once"

    @player.update_columns(welcome_pending: true)
    get home_path(locale: :en)
    assert_select "#welcome-panel"
    assert_select "#release-note-dialog", 0
  end

  test "the app opens the note in a native sheet, whose page shows it with a button that closes the sheet" do
    note = write_release_note("v1.3.0")
    run_release("v1.3.0")
    sign_in(@player)

    assert_enqueued_with(job: Accounts::SeeReleaseNoteJob, args: [ @player.id, note.id ]) do
      get home_path(locale: :en), headers: { "User-Agent" => APP }
    end
    assert_select "#release-note-dialog", 0
    assert_select "[data-controller=release-note-sheet][data-release-note-sheet-url-value='/en/me/sheets/release-note']"

    get release_note_sheet_path(locale: :en), headers: { "User-Agent" => APP }

    assert_response :success
    assert_select "body.sheet-body .release-note-sheet" do
      assert_select ".release-note-kicker", /Update installed · v1.3.0/
      assert_select "h2.release-note__title", "Capsules open at once"
      assert_select "[data-controller='bridge--sheet-close'] a.button[data-action='bridge--sheet-close#close']", "Got it"
    end
  end

  test "the sheet answers not found while no note runs" do
    run_release("v1.3.0-rc.1")
    sign_in(@player)

    get release_note_sheet_path(locale: :en)

    assert_response :not_found
  end

  test "administrators are reminded on every page while the running release has no note, until one is ready or skipped" do
    run_release("v1.3.0")
    sign_in(accounts_players(:administrator))

    get home_path(locale: :en)
    assert_select "aside.release-reminder[data-release-reminder='v1.3.0']" do
      assert_select ".release-reminder__message", "Production runs v1.3.0 and players have no note for it."
      assert_select "form[action='/en/back-office/release-notes'] input[name=version][value='v1.3.0']", 2
      assert_select "form input[name=state][value=skipped]"
    end
    get back_office_release_notes_path(locale: :en)
    assert_select "aside.release-reminder"

    write_release_note("v1.3.0", state: "skipped", title_en: "", body_en: "")
    get home_path(locale: :en)
    assert_select "aside.release-reminder", 0
  end

  test "players and moderators are never reminded, nor anyone on a candidate" do
    run_release("v1.3.0")
    [ @player, accounts_players(:moderator) ].each do |player|
      sign_in(player)
      get home_path(locale: :en)
      assert_select "aside.release-reminder", 0
    end

    run_release("v1.3.0-rc.1")
    sign_in(accounts_players(:administrator))
    get home_path(locale: :en)
    assert_select "aside.release-reminder", 0
  end
end
