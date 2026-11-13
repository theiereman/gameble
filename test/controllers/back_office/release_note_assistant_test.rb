require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/running_release"
require_relative "../../support/claude_writer_stubs"

module BackOffice
  # Claude's help in the release-note editor: asking answers at once and leaves Claude to a job, whose answer
  # comes back to the page on its own stream; neither saves anything.
  class ReleaseNoteAssistantTest < ActionDispatch::IntegrationTest
    include SteamSignIn
    include RunningRelease
    include ClaudeWriterStubs
    include ActiveJob::TestHelper

    TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html" }.freeze
    PAGE = "0f1e2d3c-4b5a-4968-8776-a5b4c3d2e1f0".freeze

    def assistant_jobs = [ CondenseReleaseNoteJob, TranslateReleaseNoteJob ]

    setup do
      @note = write_release_note("v1.3.0", state: "draft", title_en: "", body_en: "")
      sign_in(accounts_players(:administrator))
    end

    def texts(**overrides)
      { title_fr: "Les capsules s'ouvrent", body_fr: "## Nouveautés\n- Une capsule s'ouvre", title_en: "", body_en: "", preview_locale: "en", assistant_page: PAGE }.merge(overrides)
    end

    test "the editor offers Claude's help with a key, and says it is off without one" do
      with_anthropic_key
      get edit_back_office_release_note_path(locale: :fr, token: @note.token)
      assert_select "button[formaction='/fr/back-office/release-notes/#{@note.token}/condense']", "Condenser avec Claude"
      assert_select "button[formaction='/fr/back-office/release-notes/translate']", "Traduire en anglais"
      assert_select "#release-note-review"
      assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel'][signed-stream-name]"
      assert ReleaseNoteAssistantStream.page?(css_select("input[type=hidden][name=assistant_page]").sole["value"])

      without_anthropic_key
      get edit_back_office_release_note_path(locale: :fr, token: @note.token)
      assert_select "button[formaction$=condense]", false
      assert_select "[data-claude-writer-missing]", /ANTHROPIC_API_KEY/
    end

    test "translating answers at once with a waiting status and leaves Claude to a job" do
      stub_singleton(Accounts::ClaudeWriter, :translate, ->(**) { flunk "Claude is asked in the request" }) do
        post translate_back_office_release_notes_path(locale: :fr), params: texts, headers: TURBO_STREAM
      end

      assert_response :success
      assert_select "turbo-stream[action=update][target=release-note-assistant-status] [data-claude-writer-waiting]", /Claude traduit/
      assert_select "turbo-stream[target=release-note-language-en]", false
      job = enqueued_jobs.select { it[:job] == TranslateReleaseNoteJob }.sole
      stream, sent, preview_locale = ActiveJob::Arguments.deserialize(job[:args])
      assert_equal ReleaseNoteAssistantStream.streamables(accounts_players(:administrator), PAGE), stream
      assert_equal "Les capsules s'ouvrent", sent[:title_fr]
      assert_equal "en", preview_locale
      assert_equal "", @note.reload.title_en
    end

    test "nothing to translate says why at once and asks no job" do
      post translate_back_office_release_notes_path(locale: :en), params: texts(title_fr: " ", body_fr: ""), headers: TURBO_STREAM

      assert_response :unprocessable_content
      assert_select "turbo-stream[target=release-note-assistant-status]", "Write the French title or text first."
      assert_no_enqueued_jobs(only: assistant_jobs)
    end

    test "condensing answers at once with a waiting status and leaves GitHub and Claude to a job" do
      stub_singleton(Accounts::GithubReleaseChanges, :for, ->(_version) { flunk "GitHub is asked in the request" }) do
        post condense_back_office_release_note_path(locale: :en, token: @note.token), params: texts, headers: TURBO_STREAM
      end

      assert_response :success
      assert_select "turbo-stream[action=update][target=release-note-assistant-status] [data-claude-writer-waiting]",
        /Claude is reading the commits.*within a minute/m
      assert_enqueued_with(job: CondenseReleaseNoteJob,
        args: [ ReleaseNoteAssistantStream.streamables(accounts_players(:administrator), PAGE), @note.token ])
      assert_equal "## Nouveautés\n- Les capsules s'ouvrent d'un coup", @note.reload.body_fr
    end

    test "a page from before the answers came by stream is asked to reload" do
      post condense_back_office_release_note_path(locale: :en, token: @note.token), params: texts(assistant_page: ""), headers: TURBO_STREAM

      assert_response :unprocessable_content
      assert_select "turbo-stream[target=release-note-assistant-status]", /Reload it, then ask Claude again/
      assert_no_enqueued_jobs(only: assistant_jobs)
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
