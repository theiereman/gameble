# The reactions of the feed's entries, kept current in every open feed, one
# stream per locale: a reaction sends its entry's count per kind and the names
# a summary shows, never a database id.
module ReactionStream
  EVENTS = [ Game::FeedEntryReacted ].freeze

  BATCHES = :reaction_stream_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |entry_ids| ReactionCountsJob.perform_later(entry_ids.uniq) }

  class << self
    def streamables(locale = I18n.locale) = [ "reactions", locale.to_s ]

    def call(event)
      BATCH.add([ event.data[:feed_entry_id] ])
    end

    def slot(token, kind) = "#{token}-#{kind}"

    def count_targets(token, kind) = %([data-reaction-count="#{slot(token, kind)}"])

    def names_targets(token, kind) = %([data-reaction-names="#{slot(token, kind)}"])
  end
end
