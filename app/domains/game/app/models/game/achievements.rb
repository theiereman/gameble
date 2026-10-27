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
      Achievement.new(:first_repost, :reposts, 1)
    ].freeze

    BY_KEY = CATALOGUE.index_by { it.key.to_s }.freeze

    def self.find(key)
      BY_KEY[key.to_s]
    end

    def self.met(progress)
      CATALOGUE.select { it.met?(progress) }
    end
  end
end
