require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/claude_writer_stubs"

module BackOffice
  # Claude fills the English of the roadmap lines that have none, from their French, without saving.
  class RoadmapTranslationTest < ActionDispatch::IntegrationTest
    include SteamSignIn
    include ClaudeWriterStubs

    TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

    setup { sign_in(accounts_players(:administrator)) }

    def row(french, english, **stories)
      { "wording_fr" => french, "wording_en" => english, "status" => "to_come", "shown" => "1", "stories" => stories }
    end

    def form
      { preview_locale: "en", milestones: {
        "m1" => row("Les échanges", "", "s1" => row("Proposer un échange", ""), "s2" => row("Annuler", "Cancel")),
        "m2" => row("", "") } }
    end

    test "the editor offers to translate with a key, and says Claude's help is off without one" do
      with_anthropic_key
      get back_office_roadmap_path(locale: :fr)
      assert_select "button[formaction='/fr/back-office/roadmap/translate']", "Traduire en anglais les lignes vides"

      without_anthropic_key
      get back_office_roadmap_path(locale: :fr)
      assert_select "button[formaction$=translate]", false
      assert_select "[data-claude-writer-missing]"
    end

    test "only the lines with French and no English go to Claude, and come back into their fields and the preview" do
      sent = nil
      translate = lambda do |wordings, length:|
        sent = [ wordings, length ]
        { "m1" => "Trades", "s1" => "Offer a trade" }
      end
      stub_singleton(Accounts::ClaudeWriter, :translate_wordings, translate) do
        post translate_back_office_roadmap_path(locale: :fr), params: form, headers: TURBO_STREAM
      end

      assert_response :success
      assert_equal [ { "m1" => "Les échanges", "s1" => "Proposer un échange" }, 200 ], sent
      assert_select "turbo-stream[action=replace][target=roadmap-milestone-m1-wording-en] input[name='milestones[m1][wording_en]'][value=Trades]"
      assert_select "turbo-stream[action=replace][target=roadmap-story-s1-wording-en] input[name='milestones[m1][stories][s1][wording_en]'][value='Offer a trade']"
      assert_select "turbo-stream[target=roadmap-story-s2-wording-en]", false
      assert_select "turbo-stream[target=roadmap-preview]", /Trades/
      assert_select "turbo-stream[target=roadmap-translation-status]", /Claude a traduit 2 lignes/
    end

    test "nothing to translate, or no answer from Claude, says so and changes no field" do
      complete = { milestones: { "m1" => row("Les échanges", "Trades") } }
      post translate_back_office_roadmap_path(locale: :en), params: complete, headers: TURBO_STREAM
      assert_response :unprocessable_content
      assert_select "turbo-stream[target=roadmap-translation-status]", /nothing to translate/

      stub_singleton(Accounts::ClaudeWriter, :translate_wordings, ->(*, **) { nil }) do
        post translate_back_office_roadmap_path(locale: :en), params: form, headers: TURBO_STREAM
      end
      assert_response :unprocessable_content
      assert_select "turbo-stream[target=roadmap-translation-status]", /Claude could not answer/
      assert_select "turbo-stream[action=replace]", false
    end

    test "only an administrator asks Claude to translate the roadmap" do
      sign_in(accounts_players(:moderator))
      post translate_back_office_roadmap_path(locale: :en), params: form, headers: TURBO_STREAM
      assert_response :forbidden
    end
  end
end
