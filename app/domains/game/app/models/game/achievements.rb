module Game
  module Achievements
    Achievement = Data.define(:key, :metric, :threshold) do
      def met?(progress)
        progress.fetch(metric) >= threshold
      end
    end

    CATALOGUE = [
      Achievement.new(:first_booster, :packs_opened, 1),
      Achievement.new(:first_epic, :epics_obtained, 1),
      Achievement.new(:first_legendary, :legendaries_obtained, 1),
      Achievement.new(:first_complete_set, :sets_completed, 1),
      Achievement.new(:first_trade, :trades_accepted, 1),
      Achievement.new(:boosters_10, :packs_opened, 10),
      Achievement.new(:boosters_100, :packs_opened, 100),
      Achievement.new(:boosters_500, :packs_opened, 500),
      Achievement.new(:three_complete_sets, :sets_completed, 3),
      Achievement.new(:first_repost, :reposts, 1),
      Achievement.new(:statistical_non_compliance, :two_rare_or_better_capsules, 1),
      Achievement.new(:packaging_irregularity, :repeated_game_capsules, 1),
      Achievement.new(:excellence_in_mediocrity, :all_common_capsules, 1),
      Achievement.new(:historical_asset_management, :old_and_new_game_capsules, 1),
      Achievement.new(:luck_is_a_marketing_concept, :capsules_without_rare_streak, 10),
      Achievement.new(:leave_request_denied, :daily_bonus_streak, 7),
      Achievement.new(:streamlined_opening_procedure, :reveal_all_streak, 10),
      Achievement.new(:diligence_beyond_the_call_of_duty, :reveal_one_by_one_streak, 10),
      Achievement.new(:diversified_portfolio, :most_copies_of_a_game, 5),
      Achievement.new(:market_concentration, :most_games_of_a_studio, 10),
      Achievement.new(:first_claim_all_rights_reserved, :first_discoveries, 1),
      Achievement.new(:a_discovery_of_ours, :pioneered_reposts, 1),
      Achievement.new(:a_strictly_professional_relationship, :most_trades_with_a_partner, 3),
      Achievement.new(:no_time_to_waste, :quick_capsule_bursts, 1),
      Achievement.new(:night_owl, :night_capsules, 1),
      Achievement.new(:hostile_takeover, :comeback_wins, 1),
      Achievement.new(:competitive_tender, :most_bidders_on_a_sale, 3),
      Achievement.new(:capital_gain, :doubled_resales, 1),
      Achievement.new(:quarterly_targets_met, :cards_sold, 25),
      Achievement.new(:insider_trading, :doubled_resales, 5),
      Achievement.new(:boosters_1000, :packs_opened, 1_000),
      Achievement.new(:boosters_5000, :packs_opened, 5_000),
      Achievement.new(:boosters_10000, :packs_opened, 10_000),
      Achievement.new(:reposts_10, :reposts, 10),
      Achievement.new(:reposts_50, :reposts, 50),
      Achievement.new(:reposts_200, :reposts, 200),
      Achievement.new(:trades_10, :trades_accepted, 10),
      Achievement.new(:trades_50, :trades_accepted, 50),
      Achievement.new(:trades_100, :trades_accepted, 100),
      Achievement.new(:picoins_50k, :picoins_held, 50_000),
      Achievement.new(:picoins_500k, :picoins_held, 500_000),
      Achievement.new(:picoins_1m, :picoins_held, 1_000_000),
      Achievement.new(:friends_10, :friends, 10),
      Achievement.new(:friends_25, :friends, 25),
      Achievement.new(:friends_50, :friends, 50),
      Achievement.new(:reactions_50, :reactions_given, 50),
      Achievement.new(:reactions_200, :reactions_given, 200),
      Achievement.new(:reactions_500, :reactions_given, 500),
      Achievement.new(:self_assessment, :reactions_to_own_posts, 1),
      Achievement.new(:viral_memo, :most_reactions_on_a_post, 10),
      Achievement.new(:showcase_full, :showcase_cards, ShowcaseEntry::SIZE),
      Achievement.new(:everything_must_go, :showcase_cleared_after_full, 1),
      Achievement.new(:entrusted_100, :cards_entrusted, 100),
      Achievement.new(:entrusted_1000, :cards_entrusted, 1_000),
      Achievement.new(:entrusted_5000, :cards_entrusted, 5_000),
      Achievement.new(:entrusted_10000, :cards_entrusted, 10_000),
      Achievement.new(:employee_of_the_week, :verdicts_won, 1),
      Achievement.new(:room_for_improvement, :last_places, 1),
      Achievement.new(:sustained_growth, :lucky_week_streak, 3),
      Achievement.new(:turnaround_plan, :unlucky_week_streak, 3),
      Achievement.new(:statement_of_requirements, :largest_custom_set, 10),
      Achievement.new(:delivered_on_schedule, :largest_completed_custom_set, 10),
      Achievement.new(:goals_10, :goals_completed, 10),
      Achievement.new(:goals_25, :goals_completed, 25),
      Achievement.new(:goals_50, :goals_completed, 50),
      Achievement.new(:avatar_changed, :avatar_choices, 1),
      Achievement.new(:avatar_rebrand, :avatar_choices, 5),
      Achievement.new(:source_audit, :source_code_opened, 1),
      Achievement.new(:funding_review, :support_opened, 1)
    ].freeze

    BY_KEY = CATALOGUE.index_by { it.key.to_s }.freeze

    def self.find(key)
      BY_KEY[key.to_s]
    end

    def self.unearned(unlocked_keys)
      CATALOGUE.reject { unlocked_keys.include?(it.key) }
    end

    def self.metrics(achievements)
      achievements.map(&:metric).uniq
    end
  end
end
