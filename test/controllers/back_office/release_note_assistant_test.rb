require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/running_release"
require_relative "../../support/claude_writer_stubs"

module BackOffice
  # Claude's help in the release-note editor: it condenses the version's commits into a suggestion to review
  # commit by commit, and fills the English from the French; neither saves anything.
  class ReleaseNoteAssistantTest < ActionDispatch::IntegrationTest
    include SteamSignIn
    include RunningRelease
    include ClaudeWriterStubs

    TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

    setup do
      @note = write_release_note("v1.3.0", state: "draft", title_en: "", body_en: "")
      sign_in(accounts_players(:administrator))
    end

    def texts(**overrides)
      { title_fr: "Les capsules s'ouvrent", body_fr: "## Nouveautés\n- Une capsule s'ouvre", title_en: "", body_en: "", preview_locale: "en" }.merge(overrides)
    end

    def changes
      Accounts::ReleaseChanges.new(since: "v1.2.1", head: "v1.3.0-rc.1", commits: [
        { subject: "feat(booster): a capsule opens at once", credits: [ "ana" ] },
        { subject: "fix: a typo", credits: [] }
      ])
    end

    def condensed
      Accounts::CondensedChanges.new(changes, {
        "title" => "Les capsules s'ouvrent à l'instant", "intro" => "",
        "lines" => [ { "section" => "features", "text" => "Une capsule s'ouvre tout de suite.", "sources" => %w[f1] } ], "dropped" => []
      })
    end

    test "the editor offers Claude's help with a key, and says it is off without one" do
      with_anthropic_key
      get edit_back_office_release_note_path(locale: :fr, token: @note.token)
      assert_select "button[formaction='/fr/back-office/release-notes/#{@note.token}/condense']", "Condenser avec Claude"
      assert_select "button[formaction='/fr/back-office/release-notes/translate']", "Traduire en anglais"
      assert_select "#release-note-review"

      without_anthropic_key
      get edit_back_office_release_note_path(locale: :fr, token: @note.token)
      assert_select "button[formaction$=condense]", false
      assert_select "[data-claude-writer-missing]", /ANTHROPIC_API_KEY/
    end

    test "translating fills the English fields and the preview, without saving" do
      translate = ->(title:, body:) { { title: "Capsules open (#{title.size})", body: "## New\n#{body.lines.last}" } }
      stub_singleton(Accounts::ClaudeWriter, :translate, translate) do
        post translate_back_office_release_notes_path(locale: :fr), params: texts, headers: TURBO_STREAM
      end

      assert_response :success
      assert_select "turbo-stream[action=replace][target=release-note-language-en]" do
        assert_select "input[name=title_en][value='Capsules open (22)']"
        assert_select "textarea[name=body_en]", "## New\n- Une capsule s'ouvre"
      end
      assert_select "turbo-stream[target=release-note-preview] .release-note__item", "Une capsule s'ouvre"
      assert_select "turbo-stream[target=release-note-assistant-status]", /L'anglais est rempli/
      assert_equal "", @note.reload.title_en
    end

    test "nothing to translate, or no answer, leaves the fields as they are and says why" do
      post translate_back_office_release_notes_path(locale: :en), params: texts(title_fr: " ", body_fr: ""), headers: TURBO_STREAM
      assert_response :unprocessable_content
      assert_select "turbo-stream[target=release-note-assistant-status]", "Write the French title or text first."

      stub_singleton(Accounts::ClaudeWriter, :translate, ->(**) { nil }) do
        post translate_back_office_release_notes_path(locale: :en), params: texts, headers: TURBO_STREAM
      end
      assert_response :unprocessable_content
      assert_select "turbo-stream[target=release-note-assistant-status]", /Claude could not answer/
      assert_select "turbo-stream[target=release-note-language-en]", false
    end

    test "condensing shows Claude's note beside every commit, with the note to use in one click" do
      changes = self.changes
      suggestion = condensed
      stub_singleton(Accounts::GithubReleaseChanges, :for, ->(version) { changes if version.to_s == "v1.3.0" }) do
        stub_singleton(Accounts::ClaudeWriter, :condense, ->(_changes) { suggestion }) do
          post condense_back_office_release_note_path(locale: :fr, token: @note.token), params: texts, headers: TURBO_STREAM
        end
      end

      assert_response :success
      assert_select "turbo-stream[action=update][target=release-note-review]" do
        assert_select "[data-release-note-review-summary]", /2 commits\u202f: repris 1, écartés 0, oubliés 1/
        assert_select "[data-release-note-line='1']", /Une capsule s'ouvre tout de suite.*@ana/m
        assert_select "[data-release-note-source=kept]", /Repris ligne 1/
        assert_select "[data-release-note-source=forgotten]", /A typo.*Oublié par Claude/m
        assert_select "button[data-action='release-note-editor#apply']" \
          "[data-release-note-editor-title-param=\"Les capsules s'ouvrent à l'instant\"]" \
          "[data-release-note-editor-body-param=\"## Nouveautés\n- Une capsule s'ouvre tout de suite. (merci @ana)\"]"
      end
      assert_equal "## Nouveautés\n- Les capsules s'ouvrent d'un coup", @note.reload.body_fr
    end

    test "condensing says so when GitHub gives no changes for the version" do
      stub_singleton(Accounts::GithubReleaseChanges, :for, ->(_version) { nil }) do
        post condense_back_office_release_note_path(locale: :en, token: @note.token), params: texts, headers: TURBO_STREAM
      end

      assert_response :unprocessable_content
      assert_select "turbo-stream[target=release-note-assistant-status]", /GitHub gave no new features/
    end

    test "only an administrator asks Claude" do
      sign_in(accounts_players(:moderator))

      post translate_back_office_release_notes_path(locale: :en), params: texts, headers: TURBO_STREAM
      assert_response :forbidden
      post condense_back_office_release_note_path(locale: :en, token: @note.token), params: texts, headers: TURBO_STREAM
      assert_response :forbidden
    end
  end
end
