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

    REPEATED_GAME_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_packs
       WHERE game_packs.player_id = :player_id AND game_packs.opened_at IS NOT NULL
         AND (SELECT COUNT(*) - COUNT(DISTINCT catalog_card_seasons.card_id) FROM unnest(game_packs.card_season_ids) AS drawn(card_season_id)
                JOIN catalog_card_seasons ON catalog_card_seasons.id = drawn.card_season_id) > 0
    SQL

    ALL_COMMON_SQL = format(<<~SQL.squish, Catalog::Rarity::TIERS.key(:common), Pack::SIZE).freeze
      SELECT COUNT(*) FROM game_packs
       WHERE game_packs.player_id = :player_id AND game_packs.kind = 'regular' AND game_packs.opened_at IS NOT NULL
         AND (SELECT COUNT(*) FROM unnest(game_packs.card_season_ids) AS drawn(card_season_id)
                JOIN catalog_card_seasons ON catalog_card_seasons.id = drawn.card_season_id
               WHERE catalog_card_seasons.rarity = %d) >= %d
    SQL

    OLD_AND_NEW_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_packs
       WHERE game_packs.player_id = :player_id AND game_packs.opened_at IS NOT NULL
         AND EXISTS (SELECT 1 FROM unnest(game_packs.card_season_ids) AS drawn(card_season_id)
                       JOIN catalog_card_seasons ON catalog_card_seasons.id = drawn.card_season_id
                       JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
                      WHERE catalog_cards.release_date < DATE '2000-01-01')
         AND EXISTS (SELECT 1 FROM unnest(game_packs.card_season_ids) AS drawn(card_season_id)
                       JOIN catalog_card_seasons ON catalog_card_seasons.id = drawn.card_season_id
                       JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
                      WHERE catalog_cards.release_date >= DATE '2025-01-01')
    SQL

    CAPSULES_WITHOUT_RARE_STREAK_SQL = format(<<~SQL.squish, Catalog::Rarity::TIERS.key(:rare)).freeze
      SELECT COALESCE(MAX(run_length), 0) FROM (
        SELECT COUNT(*) AS run_length FROM (
          SELECT lucky, ROW_NUMBER() OVER (ORDER BY opened_at, id) - ROW_NUMBER() OVER (PARTITION BY lucky ORDER BY opened_at, id) AS run
            FROM (SELECT id, opened_at,
                         EXISTS (SELECT 1 FROM unnest(game_packs.card_season_ids) AS drawn(card_season_id)
                                   JOIN catalog_card_seasons ON catalog_card_seasons.id = drawn.card_season_id
                                  WHERE catalog_card_seasons.rarity >= %d) AS lucky
                    FROM game_packs
                   WHERE game_packs.player_id = :player_id AND game_packs.kind = 'regular' AND game_packs.opened_at IS NOT NULL) AS capsules
        ) AS numbered
        WHERE NOT lucky GROUP BY run
      ) AS runs
    SQL

    DAILY_BONUS_STREAK_SQL = <<~SQL.squish.freeze
      SELECT COALESCE(MAX(run_length), 0) FROM (
        SELECT COUNT(*) AS run_length FROM (
          SELECT day - CAST(ROW_NUMBER() OVER (ORDER BY day) AS integer) AS run
            FROM game_daily_bonus_claims WHERE player_id = :player_id
        ) AS numbered
        GROUP BY run
      ) AS runs
    SQL

    REVEAL_STREAK_SQL = <<~SQL.squish.freeze
      SELECT COALESCE(MAX(run_length), 0) FROM (
        SELECT COUNT(*) AS run_length FROM (
          SELECT revealed, ROW_NUMBER() OVER (ORDER BY opened_at, id) - ROW_NUMBER() OVER (PARTITION BY revealed ORDER BY opened_at, id) AS run
            FROM (SELECT id, opened_at, COALESCE(reveal_mode = '%s', FALSE) AS revealed
                    FROM game_packs
                   WHERE game_packs.player_id = :player_id AND game_packs.opened_at IS NOT NULL) AS capsules
        ) AS numbered
        WHERE revealed GROUP BY run
      ) AS runs
    SQL

    MOST_COPIES_OF_A_GAME_SQL = <<~SQL.squish.freeze
      SELECT COALESCE(MAX(copies), 0) FROM (
        SELECT SUM(game_holdings.quantity) AS copies FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
         WHERE game_holdings.player_id = :player_id
         GROUP BY catalog_card_seasons.card_id
      ) AS held
    SQL

    HELD_GAMES_SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.card_id FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id
       GROUP BY catalog_card_seasons.card_id HAVING SUM(game_holdings.quantity) > 0
    SQL

    FIRST_DISCOVERIES_SQL = "SELECT COUNT(*) FROM game_first_discoveries WHERE player_id = :player_id".freeze

    PIONEERED_REPOSTS_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_feed_entries
        JOIN game_first_discoveries ON game_first_discoveries.card_season_id = game_feed_entries.card_season_id
                                   AND game_first_discoveries.player_id = game_feed_entries.player_id
       WHERE game_feed_entries.kind = 'repost' AND game_feed_entries.player_id = :player_id
    SQL

    MOST_TRADES_WITH_A_PARTNER_SQL = <<~SQL.squish.freeze
      SELECT COALESCE(MAX(trades), 0) FROM (
        SELECT COUNT(*) AS trades FROM game_trades
         WHERE status = 'accepted' AND (proposer_id = :player_id OR recipient_id = :player_id)
         GROUP BY CASE WHEN proposer_id = :player_id THEN recipient_id ELSE proposer_id END
      ) AS partners
    SQL

    METRIC_SQL = {
      packs_opened: PACKS_OPENED_SQL,
      epics_obtained: format(OBTAINED_SQL, Catalog::Rarity::TIERS.key(:epic)),
      legendaries_obtained: format(OBTAINED_SQL, Catalog::Rarity::TIERS.key(:legendary)),
      sets_completed: SETS_COMPLETED_SQL,
      trades_accepted: TRADES_ACCEPTED_SQL,
      reposts: REPOSTS_SQL,
      two_rare_or_better_capsules: TWO_RARE_OR_BETTER_SQL,
      repeated_game_capsules: REPEATED_GAME_SQL,
      all_common_capsules: ALL_COMMON_SQL,
      old_and_new_game_capsules: OLD_AND_NEW_SQL,
      capsules_without_rare_streak: CAPSULES_WITHOUT_RARE_STREAK_SQL,
      daily_bonus_streak: DAILY_BONUS_STREAK_SQL,
      reveal_all_streak: format(REVEAL_STREAK_SQL, "all"),
      reveal_one_by_one_streak: format(REVEAL_STREAK_SQL, "one_by_one"),
      most_copies_of_a_game: MOST_COPIES_OF_A_GAME_SQL,
      first_discoveries: FIRST_DISCOVERIES_SQL,
      pioneered_reposts: PIONEERED_REPOSTS_SQL,
      most_trades_with_a_partner: MOST_TRADES_WITH_A_PARTNER_SQL
    }.freeze

    STUDIO_METRIC = :most_games_of_a_studio

    METRICS = (METRIC_SQL.keys + [ STUDIO_METRIC ]).freeze

    def self.call(player, metrics)
      metrics = metrics.uniq
      return metrics.index_with(0) if player.nil?
      return {} if metrics.empty?

      read = sql_metrics(player, metrics - [ STUDIO_METRIC ])
      read[STUDIO_METRIC] = most_games_of_a_studio(player) if metrics.include?(STUDIO_METRIC)
      metrics.index_with { read.fetch(it) }
    end

    def self.sql_metrics(player, metrics)
      return {} if metrics.empty?

      sql = "SELECT #{metrics.map { "(#{METRIC_SQL.fetch(it)})" }.join(", ")}"
      row = Pack.connection.select_rows(sanitized(sql, player), "Game::AchievementProgress").first
      metrics.zip(row.map(&:to_i)).to_h
    end

    def self.most_games_of_a_studio(player)
      card_ids = Pack.connection.select_values(sanitized(HELD_GAMES_SQL, player), "Game::AchievementProgress").map(&:to_i)
      Catalog::StudioKeys.call(card_ids).values.tally.values.max || 0
    end

    def self.sanitized(sql, player) = Pack.sanitize_sql_array([ sql, { player_id: player.id } ])

    private_class_method :sql_metrics, :most_games_of_a_studio, :sanitized
  end
end
