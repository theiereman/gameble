require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"
require_relative "../../support/running_release"

module BackOffice
  # The release notes of the back-office, administrators only: one per
  # production release, drafted from its commits on GitHub, previewed, then
  # marked ready, or marked as needing none.
  class ReleaseNotesControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn
    include RunningRelease

    setup do
      @administrator = accounts_players(:administrator)
      @stubs = Faraday::Adapter::Test::Stubs.new
      @adapter_was = Accounts::GithubReleaseChanges.connection_adapter
      Accounts::GithubReleaseChanges.connection_adapter = [ :test, @stubs ]
    end

    teardown { Accounts::GithubReleaseChanges.connection_adapter = @adapter_was }

    def stub_github(tags:, range:, subjects:)
      json = { "Content-Type" => "application/json" }
      @stubs.get("/repos/theiereman/gameble/tags") { [ 200, json, tags.map { { name: it } }.to_json ] }
      @stubs.get("/repos/theiereman/gameble/compare/#{range}") do
        [ 200, json, { commits: subjects.map { { commit: { message: it } } } }.to_json ]
      end
    end

    test "an administrator sees every note, newest release first, and the form suggesting the running release" do
      run_release("v1.3.0")
      older = write_release_note("v1.2.0")
      newer = write_release_note("v1.10.0", state: "draft")
      Accounts::SeeReleaseNote.new.call(player_id: accounts_players(:player).id, release_note_id: older.id)
      sign_in(@administrator)

      get back_office_release_notes_path(locale: :en)

      assert_response :success
      assert_select "h1", "The release notes"
      assert_select "form[action='/en/back-office/release-notes'][method=post] input[name=version][value='v1.3.0'][required]"
      assert_equal %w[v1.10.0 v1.2.0], css_select("[data-release-note-version]").map { it["data-release-note-version"] }
      assert_select "[data-release-note-version='v1.2.0'][data-release-note-state=live]" do
        assert_select ".release-note-row__reads", "seen by 1 player"
        assert_select "a[href='/en/back-office/release-notes/#{older.token}/edit']"
      end
      assert_select "[data-release-note-version='v1.10.0'][data-release-note-state=draft]", text: /Draft/
      assert_includes response.body, newer.token
    end

    test "writing a note drafts it from the release's commits and opens its editor" do
      stub_github(tags: %w[v1.3.0-rc.2 v1.2.1], range: "v1.2.1...v1.3.0-rc.2", subjects: [ "feat(booster): a capsule opens at once", "docs: notes" ])
      sign_in(@administrator)

      post back_office_release_notes_path(locale: :fr), params: { version: "v1.3.0" }

      note = Accounts::ReleaseNotes.by_version("v1.3.0")
      assert_redirected_to "/fr/back-office/release-notes/#{note.token}/edit"
      assert_predicate note, :draft?
      assert_equal "## Nouveautés\n- A capsule opens at once", note.body_fr
      assert_equal "## New\n- A capsule opens at once", note.body_en
      assert_match(/1 nouveautés et 0 corrections tirées des commits entre v1.2.1 et v1.3.0-rc.2/, flash[:notice])
      follow_redirect!
      assert_select "h1", "La note de v1.3.0"
      assert_select "textarea[name=body_en]", "## New\n- A capsule opens at once"
      assert_select "#release-note-preview .release-note__item", "A capsule opens at once"
    end

    test "a note written while GitHub is silent starts blank; a second one for the same release opens the first" do
      @stubs.get("/repos/theiereman/gameble/tags") { [ 500, {}, "" ] }
      sign_in(@administrator)

      post back_office_release_notes_path(locale: :en), params: { version: "v1.3.0" }
      note = Accounts::ReleaseNotes.by_version("v1.3.0")
      assert_equal [ "", "" ], [ note.body_fr, note.body_en ]
      assert_match(/write it from scratch/, flash[:notice])

      assert_no_difference -> { Accounts::ReleaseNote.count } do
        post back_office_release_notes_path(locale: :en), params: { version: "v1.3.0" }
      end
      assert_redirected_to "/en/back-office/release-notes/#{note.token}/edit"

      post back_office_release_notes_path(locale: :en), params: { version: "1.3" }
      assert_redirected_to "/en/back-office/release-notes"
      assert_equal "Write the version as vMAJOR.MINOR.PATCH, like v1.3.0.", flash[:alert]
    end

    test "saving rewrites the texts; marking ready needs them complete; a release needs no note once skipped" do
      note = write_release_note("v1.3.0", state: "draft")
      sign_in(@administrator)
      texts = { title_fr: "Titre", title_en: "", body_fr: "- Un", body_en: "- One" }

      post save_back_office_release_note_path(locale: :en, token: note.token), params: texts
      assert_redirected_to "/en/back-office/release-notes/#{note.token}/edit"
      assert_equal "", note.reload.title_en

      post state_back_office_release_note_path(locale: :en, token: note.token), params: { state: "ready" }
      assert_equal "A ready note needs its title and its text in both languages.", flash[:alert]
      assert_predicate note.reload, :draft?

      post save_back_office_release_note_path(locale: :en, token: note.token), params: texts.merge(title_en: "x" * 81)
      assert_response :unprocessable_content
      assert_select "[data-release-note-failure]", "A title holds 80 characters at most, a text 1500."
      assert_select "input[name=title_en][value=?]", "x" * 81

      post save_back_office_release_note_path(locale: :en, token: note.token), params: texts.merge(title_en: "Title")
      post state_back_office_release_note_path(locale: :en, token: note.token), params: { state: "ready" }
      assert_redirected_to "/en/back-office/release-notes"
      assert_predicate note.reload, :ready?

      post back_office_release_notes_path(locale: :en), params: { version: "v1.3.1", state: "skipped" }
      assert_equal "v1.3.1 needs no note: the reminder is gone.", flash[:notice]
      assert_predicate Accounts::ReleaseNotes.by_version("v1.3.1"), :skipped?
    end

    test "the preview renders the texts in the chosen language without saving them" do
      note = write_release_note("v1.3.0", state: "draft")
      sign_in(@administrator)

      post preview_back_office_release_notes_path(locale: :en),
        params: { title_fr: "Nouveau titre", body_fr: "Intro\n## Nouveautés\n- Un", preview_locale: "fr" }, as: :turbo_stream

      assert_response :success
      assert_select "turbo-stream[action=update][target=release-note-preview] template" do
        assert_select ".release-note[lang=fr] h2.release-note__title", "Nouveau titre"
        assert_select ".release-note__text", "Intro"
        assert_select ".release-note__section-title", "Nouveautés"
      end
      assert_equal "Les capsules s'ouvrent d'un coup", note.reload.title_fr
    end

    test "a player finds no release notes, and a moderator is refused them" do
      note = write_release_note("v1.3.0")
      sign_in(accounts_players(:player))
      get back_office_release_notes_path(locale: :en)
      assert_unknown_address

      sign_in(accounts_players(:moderator))
      get back_office_release_notes_path(locale: :en)
      assert_response :forbidden
      post state_back_office_release_note_path(locale: :en, token: note.token), params: { state: "draft" }

      assert_predicate note.reload, :ready?
    end
  end
end
