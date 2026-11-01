module Game
  module Handlers
    module SeasonPublished
      def self.call(event)
        Goal.drop_unpublished(event.data.fetch(:season_id))
        HealBanksJob.perform_later
      end
    end
  end
end
