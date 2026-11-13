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
      Achievement.new(:insider_trading, :doubled_resales, 5)
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
