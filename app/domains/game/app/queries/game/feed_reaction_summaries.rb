module Game
  # The reactions of the given feed entries in one query: a count per kind,
  # the viewer's own kind, and per kind the names of the latest few players
  # who reacted, among those whose profile is public. Reactions of players
  # who are banned or deleted do not count.
  module FeedReactionSummaries
    NAMED = 3

    Summary = Data.define(:counts, :mine, :names) do
      def total = counts.values.sum
    end

    NONE = Summary.new(counts: FeedReaction::KINDS.index_with { 0 }.freeze, mine: nil, names: FeedReaction::KINDS.index_with { [].freeze }.freeze)

    def self.call(entry_ids, viewer: nil)
      return {} if entry_ids.empty?

      rows = FeedReaction.joins("JOIN #{Accounts::Player.table_name} reactor ON reactor.id = game_feed_reactions.player_id")
        .where(feed_entry_id: entry_ids, reactor: { banned_at: nil, deleted_at: nil })
        .group(:feed_entry_id, :kind)
        .pluck(:feed_entry_id, :kind, Arel.sql("COUNT(*)"), Arel.sql(own_count(viewer)), Arel.sql(latest_public_names))
      summaries = rows.group_by(&:first).transform_values { |entry_rows| summarise(entry_rows) }
      entry_ids.index_with { summaries.fetch(it, NONE) }
    end

    def self.own_count(viewer)
      FeedReaction.sanitize_sql_array([ "COUNT(*) FILTER (WHERE game_feed_reactions.player_id = ?)", viewer&.id ])
    end
    private_class_method :own_count

    def self.latest_public_names
      FeedReaction.sanitize_sql_array([ <<~SQL.squish, Accounts::Player.visibilities.fetch("public"), NAMED ])
        (ARRAY_AGG(reactor.persona_name ORDER BY game_feed_reactions.created_at DESC, game_feed_reactions.id DESC)
          FILTER (WHERE reactor.visibility = ? AND reactor.persona_name IS NOT NULL))[1:?]
      SQL
    end
    private_class_method :latest_public_names

    def self.summarise(rows)
      counts = NONE.counts.merge(rows.to_h { |_, kind, total, _, _| [ kind, total ] })
      names = NONE.names.merge(rows.to_h { |_, kind, _, _, named| [ kind, Array(named) ] })
      Summary.new(counts:, mine: rows.find { |_, _, _, own, _| own.positive? }&.at(1), names:)
    end
    private_class_method :summarise
  end
end
