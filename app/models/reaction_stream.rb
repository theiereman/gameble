# The counters of the feed's entries, kept current in every open feed: a
# reaction sends the counts of its entry, never who reacted.
module ReactionStream
  EVENTS = [ Game::FeedEntryReacted ].freeze

  BATCHES = :reaction_stream_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |entry_ids| ReactionCountsJob.perform_later(entry_ids.uniq) }

  class << self
    def streamables = [ "reactions" ]

    def call(event)
      BATCH.add([ event.data[:feed_entry_id] ])
    end

    def count_id(token, kind) = "reaction-count-#{token}-#{kind}"
  end
end
