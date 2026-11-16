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

    OWN_SALES = "sale.seller_id = :player_id AND sale.status = 'sold'".freeze

    CARDS_SOLD_SQL = "SELECT COUNT(*) FROM game_market_listings AS sale WHERE #{OWN_SALES}".freeze

    MOST_BIDDERS_ON_A_SALE_SQL = <<~SQL.squish.freeze
      SELECT COALESCE(MAX(bidders), 0) FROM (
        SELECT (SELECT COUNT(DISTINCT bid.player_id) FROM game_market_bids AS bid
                 WHERE bid.listing_id = sale.id AND bid.outcome <> 'raise'
                   AND NOT EXISTS (SELECT 1 FROM game_market_bids AS voided
                                    WHERE voided.listing_id = sale.id AND voided.player_id = bid.player_id AND voided.outcome = 'voided')) AS bidders
          FROM game_market_listings AS sale WHERE #{OWN_SALES}
      ) AS sales
    SQL

    COMEBACKS_BEFORE_WIN = 2
    COMEBACK_WINS_SQL = format(<<~SQL.squish, COMEBACKS_BEFORE_WIN).freeze
      SELECT COUNT(*) FROM (
        SELECT bid.listing_id FROM game_market_bids AS bid
          JOIN game_market_listings AS won ON won.id = bid.listing_id
         WHERE bid.player_id = :player_id AND bid.outcome = 'outbid' AND won.status = 'sold' AND won.leader_id = :player_id
           AND NOT EXISTS (SELECT 1 FROM game_market_bids AS voided
                            WHERE voided.listing_id = bid.listing_id AND voided.player_id = :player_id AND voided.outcome = 'voided')
         GROUP BY bid.listing_id HAVING COUNT(*) >= %d
      ) AS comebacks
    SQL

    RESALE_MULTIPLE = 2
    DOUBLED_RESALES_SQL = format(<<~SQL.squish, RESALE_MULTIPLE).freeze
      SELECT COUNT(DISTINCT sale.card_season_id) FROM game_market_listings AS sale
       WHERE #{OWN_SALES}
         AND EXISTS (SELECT 1 FROM game_market_listings AS bought
                      WHERE bought.card_season_id = sale.card_season_id AND bought.status = 'sold'
                        AND bought.leader_id = :player_id AND bought.sold_at <= sale.created_at
                        AND bought.final_price * %d <= sale.final_price)
    SQL

    PICOINS_HELD_SQL = "SELECT COALESCE(SUM(available + committed), 0) FROM game_market_wallets WHERE player_id = :player_id".freeze
    FRIENDS_SQL = "SELECT COUNT(*) FROM game_friendships WHERE low_player_id = :player_id OR high_player_id = :player_id".freeze
    REACTIONS_GIVEN_SQL = "SELECT COUNT(*) FROM game_feed_reactions WHERE player_id = :player_id".freeze

    REACTIONS_ON_PLAYER_ENTRIES = <<~SQL.squish.freeze
      game_feed_reactions JOIN game_feed_entries ON game_feed_entries.id = game_feed_reactions.feed_entry_id
       WHERE (game_feed_entries.player_id = :player_id OR game_feed_entries.partner_id = :player_id)
    SQL
    SELF_REACTIONS_SQL = "SELECT COUNT(*) FROM #{REACTIONS_ON_PLAYER_ENTRIES} AND game_feed_reactions.player_id = :player_id".freeze
    MOST_REACTIONS_ON_A_POST_SQL = <<~SQL.squish.freeze
      SELECT COALESCE(MAX(reactions), 0) FROM (
        SELECT COUNT(*) AS reactions FROM #{REACTIONS_ON_PLAYER_ENTRIES}
           AND game_feed_reactions.player_id <> game_feed_entries.player_id
           AND game_feed_reactions.player_id IS DISTINCT FROM game_feed_entries.partner_id
         GROUP BY game_feed_reactions.feed_entry_id
      ) AS posts
    SQL

    SHOWCASE_CARDS_SQL = "SELECT COUNT(*) FROM game_showcase_entries WHERE player_id = :player_id".freeze
    SHOWCASE_CLEARED_AFTER_FULL_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM game_achievement_unlocks
       WHERE player_id = :player_id AND achievement = 'showcase_full'
         AND NOT EXISTS (SELECT 1 FROM game_showcase_entries WHERE player_id = :player_id)
    SQL

    CARDS_ENTRUSTED_SQL = "SELECT COALESCE(SUM(quantity), 0) FROM game_market_archive_deposits WHERE player_id = :player_id".freeze
    VERDICTS_WON_SQL = "SELECT COUNT(*) FROM game_feed_entries WHERE player_id = :player_id AND kind = 'verdict'".freeze

    def self.week_run_sql(luck)
      longest_run_sql(<<~SQL.squish)
        SELECT week_start - CAST(7 * ROW_NUMBER() OVER (ORDER BY week_start) AS integer) AS run
          FROM game_fortunes WHERE player_id = :player_id AND week_start < :current_week AND z_score #{luck}
      SQL
    end

    CUSTOM_SET_SIZES = <<~SQL.squish.freeze
      SELECT COUNT(*) AS games, COUNT(*) FILTER (WHERE game_custom_set_games.card_id IN (#{HELD_GAMES_SQL})) AS held
        FROM game_custom_set_games
        JOIN game_custom_sets ON game_custom_sets.id = game_custom_set_games.custom_set_id
       WHERE game_custom_sets.player_id = :player_id AND game_custom_sets.kind = 'custom'
       GROUP BY game_custom_set_games.custom_set_id
    SQL
    LARGEST_CUSTOM_SET_SQL = "SELECT COALESCE(MAX(games), 0) FROM (#{CUSTOM_SET_SIZES}) AS custom_sets".freeze
    LARGEST_COMPLETED_CUSTOM_SET_SQL = "SELECT COALESCE(MAX(games), 0) FROM (#{CUSTOM_SET_SIZES}) AS custom_sets WHERE held = games".freeze

    GOALS_COMPLETED_SQL = "SELECT COALESCE(SUM(goals_completed), 0) FROM game_player_states WHERE player_id = :player_id".freeze
    AVATAR_CHOICES_SQL = <<~SQL.squish.freeze
      SELECT COUNT(*) FROM event_store_events
       WHERE event_type = 'Game::AvatarChosen' AND (data ->> 'player_id')::bigint = :player_id
    SQL
    SOURCE_CODE_OPENED_SQL = "SELECT COUNT(source_code_opened_at) FROM game_player_states WHERE player_id = :player_id".freeze
    SUPPORT_OPENED_SQL = "SELECT COUNT(support_opened_at) FROM game_player_states WHERE player_id = :player_id".freeze

    PROFILES_VIEWED_SQL = "SELECT COUNT(*) FROM game_profile_visits WHERE viewer_id = :player_id".freeze
    PROFILE_VISITS_SQL = "SELECT COUNT(*) FROM game_profile_visits WHERE visited_id = :player_id".freeze
    CODE_CONTRIBUTIONS_SQL = "SELECT COUNT(code_contribution_at) FROM game_player_states WHERE player_id = :player_id".freeze

    DISCORD_MEMBER_SQL = "SELECT COUNT(discord_member_at) FROM game_player_states WHERE player_id = :player_id".freeze

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
      night_capsules: NIGHT_CAPSULES_SQL,
      cards_sold: CARDS_SOLD_SQL,
      most_bidders_on_a_sale: MOST_BIDDERS_ON_A_SALE_SQL,
      comeback_wins: COMEBACK_WINS_SQL,
      doubled_resales: DOUBLED_RESALES_SQL,
      picoins_held: PICOINS_HELD_SQL,
      friends: FRIENDS_SQL,
      reactions_given: REACTIONS_GIVEN_SQL,
      reactions_to_own_posts: SELF_REACTIONS_SQL,
      most_reactions_on_a_post: MOST_REACTIONS_ON_A_POST_SQL,
      showcase_cards: SHOWCASE_CARDS_SQL,
      showcase_cleared_after_full: SHOWCASE_CLEARED_AFTER_FULL_SQL,
      cards_entrusted: CARDS_ENTRUSTED_SQL,
      verdicts_won: VERDICTS_WON_SQL,
      lucky_week_streak: week_run_sql("> 0"),
      unlucky_week_streak: week_run_sql("< 0"),
      largest_custom_set: LARGEST_CUSTOM_SET_SQL,
      largest_completed_custom_set: LARGEST_COMPLETED_CUSTOM_SET_SQL,
      goals_completed: GOALS_COMPLETED_SQL,
      avatar_choices: AVATAR_CHOICES_SQL,
      source_code_opened: SOURCE_CODE_OPENED_SQL,
      support_opened: SUPPORT_OPENED_SQL,
      code_contributions: CODE_CONTRIBUTIONS_SQL,
      profiles_viewed: PROFILES_VIEWED_SQL,
      profile_visits: PROFILE_VISITS_SQL,
      discord_member: DISCORD_MEMBER_SQL
    }.freeze

    RUBY_METRICS = %i[most_games_of_a_studio last_places].freeze

    METRICS = (METRIC_SQL.keys + RUBY_METRICS).freeze

    def self.call(player, metrics)
      metrics = metrics.uniq
      return metrics.index_with(0) if player.nil?
      return {} if metrics.empty?

      read = sql_metrics(player, metrics - RUBY_METRICS)
      (metrics & RUBY_METRICS).each { read[it] = send(it, player) }
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

    def self.last_places(player)
      mine = Fortune.listed.where(player_id: player.id, week_start: ...current_week)
      ranked_behind = listed_that_week("game_fortunes.z_score < mine.z_score OR (game_fortunes.z_score = mine.z_score AND game_fortunes.player_id > mine.player_id)")
      rival = listed_that_week("game_fortunes.player_id <> mine.player_id")
      Fortune.from(mine, :mine).where(ranked_behind.exists.not).where(rival.exists).count
    end

    def self.listed_that_week(condition) = Fortune.listed.where("game_fortunes.week_start = mine.week_start AND (#{condition})").arel

    def self.current_week = WeeklyGoal.week_start(Time.current)

    def self.sanitized(sql, player) = Pack.sanitize_sql_array([ sql, { player_id: player.id, current_week: } ])

    private_class_method :sql_metrics, :most_games_of_a_studio, :last_places, :listed_that_week, :current_week, :sanitized, :longest_run_sql,
      :pack_run_sql, :week_run_sql
  end
end
