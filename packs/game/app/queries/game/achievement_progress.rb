module Game
  module AchievementProgress
    METRICS = %i[packs_opened epics_obtained legendaries_obtained sets_completed trades_accepted reposts].freeze

    OBTAINED_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND catalog_card_seasons.rarity = %d
    SQL

    SQL = <<~SQL.squish.freeze
      SELECT
        (SELECT COUNT(*) FROM game_packs WHERE player_id = :player_id AND opened_at IS NOT NULL),
        (#{format(OBTAINED_SQL, Catalog::Rarity::TIERS.key(:epic))}),
        (#{format(OBTAINED_SQL, Catalog::Rarity::TIERS.key(:legendary))}),
        (SELECT COUNT(*) FROM game_set_completions WHERE player_id = :player_id),
        (SELECT COUNT(*) FROM game_trades WHERE status = 'accepted' AND (proposer_id = :player_id OR recipient_id = :player_id)),
        (SELECT COUNT(*) FROM game_feed_entries WHERE player_id = :player_id AND kind = 'repost')
    SQL

    def self.call(player)
      return METRICS.index_with(0) if player.nil?

      row = Pack.connection.select_rows(Pack.sanitize_sql_array([ SQL, { player_id: player.id } ]), "Game::AchievementProgress").first
      METRICS.zip(row.map(&:to_i)).to_h
    end
  end
end
