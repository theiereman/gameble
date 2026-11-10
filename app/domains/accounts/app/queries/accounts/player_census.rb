module Accounts
  module PlayerCensus
    RECENT_WINDOW = 7.days

    Figures = Data.define(:total, :joined_recently, :active_recently)

    def self.call(now:)
      since = now - RECENT_WINDOW
      total, joined, active = Player.where(deleted_at: nil).pick(
        Arel.sql("COUNT(*)"),
        counted_since("created_at", since),
        counted_since("last_seen_at", since)
      )
      Figures.new(total:, joined_recently: joined, active_recently: active)
    end

    def self.counted_since(column, since)
      Arel.sql(Player.sanitize_sql_array([ "COUNT(*) FILTER (WHERE accounts_players.#{column} >= ?)", since ]))
    end
    private_class_method :counted_since
  end
end
