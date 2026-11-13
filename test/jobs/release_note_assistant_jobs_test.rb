require "test_helper"
require_relative "../support/running_release"
require_relative "../support/claude_writer_stubs"

# Claude's answers for the release-note editor, asked in a job and sent to the one page that asked.
class ReleaseNoteAssistantJobsTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include RunningRelease
  include ClaudeWriterStubs

  PAGE = "0f1e2d3c-4b5a-4968-8776-a5b4c3d2e1f0".freeze

  setup do
    @note = write_release_note("v1.3.0", state: "draft", title_en: "", body_en: "")
    @stream = ReleaseNoteAssistantStream.streamables(accounts_players(:administrator), PAGE)
  end

  def received
    Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts(@stream.join(":")).sole))
  end

  def inside(stream)
    Nokogiri::HTML5.fragment(stream.at_css("template").inner_html)
  end

  def status
    received.css("turbo-stream[action=update][target=release-note-assistant-status]").sole.at_css("template").inner_html
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

  def texts
    { title_fr: "Les capsules s'ouvrent", body_fr: "## Nouveautés\n- Une capsule s'ouvre", title_en: "", body_en: "" }
  end

  test "condensing sends Claude's note beside every commit, with the note to use in one click" do
    changes = self.changes
    suggestion = condensed
    stub_singleton(Accounts::GithubReleaseChanges, :for, ->(version) { changes if version.to_s == "v1.3.0" }) do
      stub_singleton(Accounts::ClaudeWriter, :condense, ->(_changes) { suggestion }) do
        I18n.with_locale(:fr) { CondenseReleaseNoteJob.perform_now(@stream, @note.token) }
      end
    end

    review = inside(received.css("turbo-stream[action=update][target=release-note-review]").sole)
    assert_match(/2 commits : repris 1, écartés 0, oubliés 1/, review.at_css("[data-release-note-review-summary]").text)
    assert_match(/Une capsule s'ouvre tout de suite.*@ana/m, review.at_css("[data-release-note-line='1']").text)
    assert_match(/Repris ligne 1/, review.at_css("[data-release-note-source=kept]").text)
    assert_match(/A typo.*Oublié par Claude/m, review.at_css("[data-release-note-source=forgotten]").text)
    apply = review.at_css("button[data-action='release-note-editor#apply']")
    assert_equal "Les capsules s'ouvrent à l'instant", apply["data-release-note-editor-title-param"]
    assert_equal "## Nouveautés\n- Une capsule s'ouvre tout de suite. (merci @ana)", apply["data-release-note-editor-body-param"]
    assert_match(/Claude a relu 2 commits/, status)
    assert_equal "## Nouveautés\n- Les capsules s'ouvrent d'un coup", @note.reload.body_fr
  end

  test "condensing says so when GitHub gives no changes for the version" do
    stub_singleton(Accounts::GithubReleaseChanges, :for, ->(_version) { nil }) do
      CondenseReleaseNoteJob.perform_now(@stream, @note.token)
    end

    assert_match(/GitHub gave no new features/, status)
    assert_empty received.css("turbo-stream[target=release-note-review]")
  end

  test "translating fills the English fields and the preview, without saving" do
    translate = ->(title:, body:) { { title: "Capsules open (#{title.size})", body: "## New\n#{body.lines.last}" } }
    stub_singleton(Accounts::ClaudeWriter, :translate, translate) do
      I18n.with_locale(:fr) { TranslateReleaseNoteJob.perform_now(@stream, texts, "en") }
    end

    english = inside(received.css("turbo-stream[action=replace][target=release-note-language-en]").sole)
    assert_equal "Capsules open (22)", english.at_css("input[name=title_en]")["value"]
    assert_equal "## New\n- Une capsule s'ouvre", english.at_css("textarea[name=body_en]").text.strip
    assert_equal "Une capsule s'ouvre", inside(received.css("turbo-stream[target=release-note-preview]").sole).at_css(".release-note__item").text
    assert_match(/L'anglais est rempli/, status)
    assert_equal "", @note.reload.title_en
  end

  test "no answer from Claude says so and leaves the fields as they are" do
    with_anthropic_key
    with_claude(Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com"))) do
      TranslateReleaseNoteJob.perform_now(@stream, texts, "en")
    end

    assert_match(/Claude could not answer/, status)
    assert_empty received.css("turbo-stream[target=release-note-language-en], turbo-stream[target=release-note-preview]")
  end

  test "an unexpected error still tells the page Claude could not answer, then fails the job" do
    stub_singleton(Accounts::GithubReleaseChanges, :for, ->(_version) { raise ArgumentError, "broken" }) do
      assert_raises(ArgumentError) { CondenseReleaseNoteJob.perform_now(@stream, @note.token) }
    end

    assert_match(/Claude could not answer/, status)
  end

  test "the answer goes to the asking page only" do
    other_page = ReleaseNoteAssistantStream.streamables(accounts_players(:administrator), ReleaseNoteAssistantStream.new_page)
    stub_singleton(Accounts::GithubReleaseChanges, :for, ->(_version) { nil }) do
      CondenseReleaseNoteJob.perform_now(@stream, @note.token)
    end

    assert_broadcasts(@stream.join(":"), 1)
    assert_broadcasts(other_page.join(":"), 0)
  end
end
