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
      Achievement.new(:diversified_portfolio, :most_copies_of_a_game, 5),
      Achievement.new(:market_concentration, :most_games_of_a_studio, 10)
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
