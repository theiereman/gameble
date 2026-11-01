module Game
  module AchievementProgress
    OBTAINED_SQL = <<~SQL.squish.freeze
      SELECT COUNT(DISTINCT catalog_card_seasons.card_id) FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND catalog_card_seasons.rarity = %d
    SQL

    SETS_COMPLETED_SQL = <<~SQL.squish.freeze
      SELECT COUNT(DISTINCT (catalog_sets.kind, catalog_sets.key)) FROM game_set_tiers
        JOIN catalog_sets ON catalog_sets.id = game_set_tiers.set_id
       WHERE game_set_tiers.player_id = :player_id AND game_set_tiers.tier = 'complete'
    SQL

    PACKS_OPENED_SQL = "SELECT COUNT(*) FROM game_packs WHERE player_id = :player_id AND opened_at IS NOT NULL".freeze
    TRADES_ACCEPTED_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_trades WHERE status = 'accepted' AND (proposer_id = :player_id OR recipient_id = :player_id)
    SQL

    REPOSTS_SQL = "SELECT COUNT(*) FROM game_feed_entries WHERE player_id = :player_id AND kind = 'repost'".freeze

    TWO_RARE_OR_BETTER_SQL = format(<<~SQL.squish, Catalog::Rarity::TIERS.key(:rare)).freeze
      SELECT COUNT(*) FROM game_packs
       WHERE game_packs.player_id = :player_id AND game_packs.kind = 'regular' AND game_packs.opened_at IS NOT NULL
         AND (SELECT COUNT(*) FROM unnest(game_packs.card_season_ids) AS drawn(card_season_id)
                JOIN catalog_card_seasons ON catalog_card_seasons.id = drawn.card_season_id
               WHERE catalog_card_seasons.rarity >= %d) >= 2
    SQL

    METRIC_SQL = {
      packs_opened: PACKS_OPENED_SQL,
      epics_obtained: format(OBTAINED_SQL, Catalog::Rarity::TIERS.key(:epic)),
      legendaries_obtained: format(OBTAINED_SQL, Catalog::Rarity::TIERS.key(:legendary)),
      sets_completed: SETS_COMPLETED_SQL,
      trades_accepted: TRADES_ACCEPTED_SQL,
      reposts: REPOSTS_SQL,
      two_rare_or_better_capsules: TWO_RARE_OR_BETTER_SQL
    }.freeze

    METRICS = METRIC_SQL.keys.freeze

    def self.call(player, metrics)
      metrics = metrics.uniq
      return metrics.index_with(0) if player.nil?
      return {} if metrics.empty?

      sql = "SELECT #{metrics.map { "(#{METRIC_SQL.fetch(it)})" }.join(", ")}"
      row = Pack.connection.select_rows(Pack.sanitize_sql_array([ sql, { player_id: player.id } ]), "Game::AchievementProgress").first
      metrics.zip(row.map(&:to_i)).to_h
    end
  end
end
