require "test_helper"
require_relative "../../support/feed_reactions"

class Game::FeedReactionSummariesTest < ActiveSupport::TestCase
  include FeedReactions

  setup do
    @author = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
    @entry = feed_entry_of(@author)
  end

  test "an entry nobody reacted to counts zero of each kind and has no own reaction" do
    summary = reaction_counts(@entry, viewer: @first)

    assert_equal({ "thumb" => 0, "heart" => 0, "gg" => 0, "wow" => 0, "middle_finger" => 0 }, summary.counts)
    assert_nil summary.mine
    assert_equal 0, summary.total
  end

  test "counts per kind and the viewer's own kind" do
    react(@first, @entry, "heart")
    react(@second, @entry, "heart")
    react(@author, @entry, "gg")

    summary = reaction_counts(@entry, viewer: @first)

    assert_equal 2, summary.counts["heart"]
    assert_equal 1, summary.counts["gg"]
    assert_equal 3, summary.total
    assert_equal "heart", summary.mine
    assert_equal "gg", reaction_counts(@entry, viewer: @author).mine
    assert_nil reaction_counts(@entry).mine
  end

  test "reactions of a banned or deleted player do not count" do
    react(@first, @entry, "wow")
    react(@second, @entry, "wow")
    @first.update_columns(banned_at: Time.current)
    @second.update_columns(deleted_at: Time.current, steam_id: nil)

    assert_equal 0, reaction_counts(@entry).counts["wow"]
  end

  test "many entries are read in one query" do
    entries = Array.new(5) { feed_entry_of(@author) }
    entries.each { react(@first, it, "thumb") }

    summaries = nil
    assert_queries_count(1) { summaries = Game::FeedReactionSummaries.call(entries.map(&:id), viewer: @first) }

    assert_equal entries.map(&:id), summaries.keys
    assert(summaries.values.all? { it.mine == "thumb" })
  end

  test "no entry is no query" do
    assert_queries_count(0) { assert_equal({}, Game::FeedReactionSummaries.call([])) }
  end

  test "the summary names no player" do
    react(@first, @entry, "heart")

    assert_equal %i[counts mine], reaction_counts(@entry, viewer: @first).to_h.keys
  end
end
