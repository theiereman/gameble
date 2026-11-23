module Game
  module Handlers
    module SeasonPublished
      def self.call(event)
        Goal.drop_unpublished(event.data.fetch(:season_id))
        Market::RebuildAllWantedJob.perform_later
        HealBanksJob.perform_later
        ComputeDuelStatsJob.perform_later("season")
      end
    end
  end
end
