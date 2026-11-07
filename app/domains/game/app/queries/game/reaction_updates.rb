module Game
  # The player's feed entries that another player reacted to for the first time in the last 7 days, newest first.
  # Each comes with the time of its latest first reaction, the players reacting to it now (in good
  # standing, the entry's owners aside), how many of them chose each kind, most chosen first, and the
  # name of the latest of them whose profile is public.
  module ReactionUpdates
    WINDOW = 7.days
    PER_KIND = 5

    Update = Data.define(:entry, :noticed_at, :reactors, :name, :kinds)

    def self.call(player, now: Time.current)
      return [] unless player

      entries = noticed_entries(player, now)
      return [] if entries.empty?

      entry_ids = entries.map(&:first)
      records = FeedEntry.where(id: entry_ids).select(:id, :token, :kind, :card_season_id, :partner_card_season_id, :set_id).index_by(&:id)
      reactors = reactors_by_entry(entry_ids)
      kinds = kinds_by_entry(entry_ids)
      entries.filter_map do |entry_id, noticed_at|
        count, name = reactors[entry_id]
        Update.new(entry: records.fetch(entry_id), noticed_at:, reactors: count, name:, kinds: kinds.fetch(entry_id)) if count
      end
    end

    def self.noticed_entries(player, now)
      latest = "MAX(game_reaction_notices.created_at)"
      ReactionNotice.where(feed_entry_id: owned_entries(player).select(:id))
        .where(feed_entry_id: current_reactions.select(:feed_entry_id))
        .group(:feed_entry_id)
        .having("#{latest} >= ?", now - WINDOW)
        .order(Arel.sql("#{latest} DESC"), feed_entry_id: :desc)
        .limit(PER_KIND)
        .pluck(:feed_entry_id, Arel.sql(latest))
    end
    private_class_method :noticed_entries

    def self.owned_entries(player)
      FeedEntry.where(player_id: player.id).or(FeedEntry.where(partner_id: player.id))
    end
    private_class_method :owned_entries

    def self.current_reactions
      FeedReaction.joins(:feed_entry)
        .joins("JOIN #{Accounts::Player.table_name} reactor ON reactor.id = game_feed_reactions.player_id")
        .where(reactor: { banned_at: nil, deleted_at: nil })
        .where("game_feed_reactions.player_id <> game_feed_entries.player_id")
        .where("game_feed_entries.partner_id IS DISTINCT FROM game_feed_reactions.player_id")
    end
    private_class_method :current_reactions

    def self.reactors_by_entry(entry_ids)
      current_reactions.where(feed_entry_id: entry_ids)
        .joins(<<~SQL.squish)
          LEFT JOIN game_reaction_notices notice
            ON notice.feed_entry_id = game_feed_reactions.feed_entry_id AND notice.reactor_id = game_feed_reactions.player_id
        SQL
        .group(:feed_entry_id)
        .pluck(:feed_entry_id, Arel.sql("COUNT(*)"), Arel.sql(latest_public_name))
        .to_h { |entry_id, count, name| [ entry_id, [ count, name ] ] }
    end
    private_class_method :reactors_by_entry

    def self.kinds_by_entry(entry_ids)
      current_reactions.where(feed_entry_id: entry_ids)
        .group(:feed_entry_id, :kind)
        .pluck(:feed_entry_id, :kind, Arel.sql("COUNT(*)"))
        .group_by(&:first)
        .transform_values { |rows| rows.sort_by { |_, kind, count| [ -count, FeedReaction::KINDS.index(kind) ] }.to_h { |_, kind, count| [ kind, count ] } }
    end
    private_class_method :kinds_by_entry

    def self.latest_public_name
      FeedReaction.sanitize_sql_array([ <<~SQL.squish, Accounts::Player.visibilities.fetch("public") ])
        (ARRAY_AGG(reactor.persona_name ORDER BY notice.created_at DESC NULLS LAST, notice.id DESC NULLS LAST, game_feed_reactions.created_at DESC)
          FILTER (WHERE reactor.visibility = ? AND reactor.persona_name IS NOT NULL))[1]
      SQL
    end
    private_class_method :latest_public_name
  end
end
