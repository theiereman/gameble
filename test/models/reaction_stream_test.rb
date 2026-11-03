require "test_helper"
require_relative "../support/feed_reactions"

# The reactions kept current in every open feed: a reaction sends the counts
# of its entry and the names of public profiles through a job once it
# commits, never a token or a database id.
class ReactionStreamTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper
  include FeedReactions

  setup do
    @author = accounts_players(:player)
    @reader = accounts_players(:moderator)
    @reader.update!(persona_name: "Sam")
    @entry = feed_entry_of(@author)
  end

  def jobs = enqueued_jobs.select { it[:job] == ReactionCountsJob }

  def received
    Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts("reactions").sole))
  end

  def count_update(fragment, kind)
    fragment.at_css("turbo-stream[action=update][targets='#{ReactionStream.count_targets(@entry.token, kind)}'] template")&.text
  end

  def names_update(fragment, kind)
    fragment.at_css("turbo-stream[action=update][targets='#{ReactionStream.names_targets(@entry.token, kind)}'] template")&.text&.squish
  end

  test "the stream has a fixed name with no id" do
    assert_equal [ "reactions" ], ReactionStream.streamables
  end

  test "a reaction enqueues one job after its commit, naming the entry" do
    assert_enqueued_jobs(1, only: ReactionCountsJob) { react(@reader, @entry, "heart") }

    assert_equal [ [ @entry.id ] ], jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
  end

  test "the reactions of one transaction leave in one job, the entry named once" do
    assert_enqueued_jobs(1, only: ReactionCountsJob) do
      ApplicationRecord.transaction do
        react(@reader, @entry, "heart")
        react(@author, @entry, "wow")
        react(@reader, @entry, "gg")
      end
    end

    assert_equal [ [ @entry.id ] ], jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
  end

  test "a refused reaction, or a rolled back one, enqueues nothing" do
    assert_no_enqueued_jobs(only: ReactionCountsJob) do
      react(@reader, @entry, "angry")
      ApplicationRecord.transaction do
        react(@reader, @entry, "heart")
        raise ActiveRecord::Rollback
      end
    end
  end

  test "the job sends the five counts of the entry to the public stream, an unused kind with no count" do
    react(@reader, @entry, "heart")
    react(@author, @entry, "wow")

    ReactionCountsJob.perform_now([ @entry.id ])

    sent = received
    assert_equal({ "thumb" => "", "heart" => "1", "gg" => "", "wow" => "1", "middle_finger" => "" },
      Game::FeedReaction::KINDS.index_with { count_update(sent, it) })
    assert_no_match(/#{@reader.token}|#{@author.token}/, sent.to_html)
  end

  test "the job names the public players who reacted, and only counts the others" do
    react(@reader, @entry, "heart")
    react(@author, @entry, "wow")
    @author.update!(persona_name: "Hugo", visibility: "private")

    ReactionCountsJob.perform_now([ @entry.id ])

    sent = received
    assert_equal "Heart · 1 Sam", names_update(sent, "heart")
    assert_equal "Wow · 1 1 player", names_update(sent, "wow")
    assert_no_match(/Hugo/, sent.to_html)
  end

  test "a banned player's reaction is not counted in what is sent" do
    react(@reader, @entry, "heart")
    @reader.update!(banned_at: Time.current)

    ReactionCountsJob.perform_now([ @entry.id ])

    assert_equal "", count_update(received, "heart")
  end

  test "an entry that no longer exists sends nothing to update" do
    ReactionCountsJob.perform_now([ 0 ])

    assert_empty received.css("turbo-stream")
  end
end
