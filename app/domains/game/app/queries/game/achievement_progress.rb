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

    OPENED_PACKS = "game_packs.player_id = :player_id AND game_packs.opened_at IS NOT NULL".freeze
    OPENED_REGULAR_PACKS = "#{OPENED_PACKS} AND game_packs.kind = 'regular'".freeze
    DRAWN_CARD_SEASONS = <<~SQL.squish.freeze
      unnest(game_packs.card_season_ids) AS drawn(card_season_id)
        JOIN catalog_card_seasons ON catalog_card_seasons.id = drawn.card_season_id
    SQL
    DRAWN_CARDS = "#{DRAWN_CARD_SEASONS} JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id".freeze

    TWO_RARE_OR_BETTER_SQL = format(<<~SQL.squish, Catalog::Rarity::TIERS.key(:rare)).freeze
      SELECT COUNT(*) FROM game_packs
       WHERE #{OPENED_REGULAR_PACKS}
         AND (SELECT COUNT(*) FROM #{DRAWN_CARD_SEASONS} WHERE catalog_card_seasons.rarity >= %d) >= 2
    SQL

    REPEATED_GAME_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_packs
       WHERE #{OPENED_PACKS}
         AND (SELECT COUNT(*) - COUNT(DISTINCT catalog_card_seasons.card_id) FROM #{DRAWN_CARD_SEASONS}) > 0
    SQL

    ALL_COMMON_SQL = format(<<~SQL.squish, Catalog::Rarity::TIERS.key(:common), Pack::SIZE).freeze
      SELECT COUNT(*) FROM game_packs
       WHERE #{OPENED_REGULAR_PACKS}
         AND (SELECT COUNT(*) FROM #{DRAWN_CARD_SEASONS} WHERE catalog_card_seasons.rarity = %d) >= %d
    SQL

    OLD_AND_NEW_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_packs
       WHERE #{OPENED_PACKS}
         AND EXISTS (SELECT 1 FROM #{DRAWN_CARDS} WHERE catalog_cards.release_date < DATE '2000-01-01')
         AND EXISTS (SELECT 1 FROM #{DRAWN_CARDS} WHERE catalog_cards.release_date >= DATE '2025-01-01')
    SQL

    # Longest run of consecutive rows sharing a value, by the gaps-and-islands difference of two row numbers.
    def self.longest_run_sql(numbered, only: nil)
      <<~SQL.squish
        SELECT COALESCE(MAX(run_length), 0) FROM (
          SELECT COUNT(*) AS run_length FROM (#{numbered}) AS numbered
          #{"WHERE #{only}" if only} GROUP BY run
        ) AS runs
      SQL
    end

    def self.pack_run_sql(flag_sql, packs, only:)
      order = "ORDER BY opened_at, id"
      numbered = <<~SQL.squish
        SELECT flag, ROW_NUMBER() OVER (#{order}) - ROW_NUMBER() OVER (PARTITION BY flag #{order}) AS run
          FROM (SELECT id, opened_at, #{flag_sql} AS flag FROM game_packs WHERE #{packs}) AS capsules
      SQL
      longest_run_sql(numbered, only:)
    end

    CAPSULES_WITHOUT_RARE_STREAK_SQL = pack_run_sql(
      format("EXISTS (SELECT 1 FROM #{DRAWN_CARD_SEASONS} WHERE catalog_card_seasons.rarity >= %d)", Catalog::Rarity::TIERS.key(:rare)),
      OPENED_REGULAR_PACKS, only: "NOT flag"
    ).freeze

    DAILY_BONUS_STREAK_SQL = longest_run_sql(<<~SQL.squish).freeze
      SELECT day - CAST(ROW_NUMBER() OVER (ORDER BY day) AS integer) AS run
        FROM game_daily_bonus_claims WHERE player_id = :player_id
    SQL

    REVEAL_STREAK_SQL = pack_run_sql("COALESCE(reveal_mode = '%s', FALSE)", OPENED_PACKS, only: "flag").freeze

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

    QUICK_BURST_PACKS = 10
    QUICK_BURST_WINDOW = 30.seconds
    QUICK_BURST_SQL = format(<<~SQL.squish, QUICK_BURST_PACKS - 1, QUICK_BURST_WINDOW.to_i).freeze
      SELECT COUNT(*) FROM (
        SELECT opened_at, LEAD(opened_at, %d) OVER (ORDER BY opened_at, id) AS burst_end
          FROM game_packs WHERE #{OPENED_PACKS}
      ) AS bursts
       WHERE burst_end - opened_at < INTERVAL '%d seconds'
    SQL

    NIGHT_HOURS = (1...4)
    NIGHT_CAPSULES_SQL = format(<<~SQL.squish, NIGHT_HOURS.first, NIGHT_HOURS.last).freeze
      SELECT COUNT(*) FROM game_packs WHERE #{OPENED_PACKS} AND game_packs.opened_local_hour >= %d AND game_packs.opened_local_hour < %d
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
      most_trades_with_a_partner: MOST_TRADES_WITH_A_PARTNER_SQL,
      quick_capsule_bursts: QUICK_BURST_SQL,
      night_capsules: NIGHT_CAPSULES_SQL
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

    private_class_method :sql_metrics, :most_games_of_a_studio, :sanitized, :longest_run_sql, :pack_run_sql
  end
end
