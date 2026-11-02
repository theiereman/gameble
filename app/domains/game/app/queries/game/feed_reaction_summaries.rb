module Game
  # The reactions of the given feed entries in one query: a count per kind and
  # the viewer's own kind. Reactions of players who are banned or deleted do
  # not count. Never a player.
  module FeedReactionSummaries
    Summary = Data.define(:counts, :mine) do
      def total = counts.values.sum
    end

    NONE = Summary.new(counts: FeedReaction::KINDS.index_with { 0 }.freeze, mine: nil)

    def self.call(entry_ids, viewer: nil)
      return {} if entry_ids.empty?

      rows = FeedReaction.where(feed_entry_id: entry_ids, player_id: Accounts::Player.in_good_standing.select(:id))
        .group(:feed_entry_id, :kind)
        .pluck(:feed_entry_id, :kind, Arel.sql("COUNT(*)"), Arel.sql(FeedReaction.sanitize_sql_array([ "COUNT(*) FILTER (WHERE player_id = ?)", viewer&.id ])))
      summaries = rows.group_by(&:first).transform_values { |entry_rows| summarise(entry_rows) }
      entry_ids.index_with { summaries.fetch(it, NONE) }
    end

    def self.summarise(rows)
      counts = NONE.counts.merge(rows.to_h { |_, kind, total, _| [ kind, total ] })
      Summary.new(counts:, mine: rows.find { |_, _, _, own| own.positive? }&.at(1))
    end
    private_class_method :summarise
  end
end
