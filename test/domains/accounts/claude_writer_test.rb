require "test_helper"
require_relative "../../support/claude_writer_stubs"

# Claude condenses a release's commits into a French note, every commit traced to the line that
# keeps it or the reason it was dropped, and translates a note into English.
class Accounts::ClaudeWriterTest < ActiveSupport::TestCase
  include ClaudeWriterStubs

  def changes
    Accounts::ReleaseChanges.new(since: "v1.2.1", head: "v1.3.0-rc.1", commits: [
      { subject: "feat(booster): a capsule opens at once", credits: [ "ana" ] },
      { subject: "feat(booster): reveal cards before the server answers", credits: [ "Bob" ] },
      { subject: "feat(back-office): a release note editor", credits: [] },
      { subject: "fix(collection): a held card shows its face", credits: [ "ana" ] },
      { subject: "chore: bump rubocop", credits: [] }
    ])
  end

  def answer(**overrides)
    { "title" => "Les capsules s'ouvrent à l'instant", "intro" => "",
      "lines" => [
        { "section" => "fixes", "text" => "Une carte conservée montre sa face.", "sources" => %w[x1] },
        { "section" => "features", "text" => "- Une capsule s'ouvre tout de suite.", "sources" => %w[f1 f2 f9] }
      ],
      "dropped" => [ { "source" => "f3", "reason" => "back-office, invisible pour les joueurs" } ] }.merge(overrides)
  end

  test "the commits go to Claude by id, one per line, features before fixes and chores left out" do
    with_anthropic_key
    with_claude(answer) do |claude|
      Accounts::ClaudeWriter.condense(changes)

      request = claude.requests.sole
      assert_equal :"claude-opus-5-5", request[:model]
      assert_equal :default, request[:fallbacks]
      assert_equal :json_schema, request.dig(:output_config, :format_, :type)
      assert_equal "f1 [features] A capsule opens at once\nf2 [features] Reveal cards before the server answers\n" \
        "f3 [features] A release note editor\nx1 [fixes] A held card shows its face", request[:messages].sole[:content]
    end
  end

  test "the condensed note lists features then fixes, each line crediting its commits' contributors once" do
    with_anthropic_key
    condensed = with_claude(answer) { Accounts::ClaudeWriter.condense(changes) }

    assert_equal "## Nouveautés\n- Une capsule s'ouvre tout de suite. (merci @ana, @Bob)\n\n## Corrections\n- Une carte conservée montre sa face. (merci @ana)",
      condensed.body
    assert_equal [ [ 1, "features", %w[f1 f2] ], [ 2, "fixes", %w[x1] ] ], condensed.lines.map { [ it.number, it.section, it.sources.map(&:id) ] }
    assert_predicate condensed, :fitting?
  end

  test "every commit is traced: kept on its lines, dropped with Claude's reason, or forgotten" do
    with_anthropic_key
    condensed = with_claude(answer("lines" => answer["lines"].first(1))) { Accounts::ClaudeWriter.condense(changes) }

    statuses = condensed.reviews.to_h { [ it.source.id, [ it.kept?, it.dropped?, it.forgotten?, it.lines ] ] }
    assert_equal [ false, false, true, [] ], statuses["f1"]
    assert_equal [ false, true, false, [] ], statuses["f3"]
    assert_equal [ true, false, false, [ 1 ] ], statuses["x1"]
    assert_equal %w[f1 f2], condensed.forgotten.map { it.source.id }
  end

  test "the translation keeps the note's format, cleaned like the editor's texts" do
    with_anthropic_key
    translation = with_claude({ "title" => " Capsules open  at once ", "body" => "## New\r\n- Capsules open  \n\n\n\n- Done" }) do |claude|
      Accounts::ClaudeWriter.translate(title: "Titre", body: "## Nouveautés").tap do
        assert_equal "Title:\nTitre\n\nBody:\n## Nouveautés", claude.requests.sole[:messages].sole[:content]
        assert_match "\"## Nouveautés\" = \"## New\"", claude.requests.sole.dig(:system_, 0, :text)
      end
    end

    assert_equal({ title: "Capsules open at once", body: "## New\n- Capsules open\n\n- Done" }, translation)
  end

  test "no answer without a key, on a refusal, a cut answer, broken JSON or an API error" do
    without_anthropic_key
    assert_not Accounts::ClaudeWriter.available?
    assert_nil Accounts::ClaudeWriter.translate(title: "Titre", body: "")

    with_anthropic_key
    assert_nil with_claude(answer, stop_reason: :refusal) { Accounts::ClaudeWriter.condense(changes) }
    assert_nil with_claude(answer, stop_reason: :max_tokens) { Accounts::ClaudeWriter.condense(changes) }
    assert_nil with_claude("{\"title\":") { Accounts::ClaudeWriter.translate(title: "Titre", body: "") }
    error = Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com"))
    assert_nil with_claude(error) { Accounts::ClaudeWriter.translate(title: "Titre", body: "") }
  end

  test "roadmap lines go to Claude by key and only the keys asked come back" do
    with_anthropic_key
    answer = { "translations" => [ { "key" => "m1", "english" => " Trades " }, { "key" => "ghost", "english" => "Boo" } ] }
    translations = with_claude(answer) do |claude|
      Accounts::ClaudeWriter.translate_wordings({ "m1" => "Les  échanges", "s1" => "Proposer" }, length: 200).tap do
        assert_equal "m1: Les échanges\ns1: Proposer", claude.requests.sole[:messages].sole[:content]
        assert_match "never longer than 200 characters", claude.requests.sole.dig(:system_, 0, :text)
      end
    end

    assert_equal({ "m1" => "Trades" }, translations)
  end
end
