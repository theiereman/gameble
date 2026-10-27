module Game
  module Handlers
    module SeasonPublished
      def self.call(_event)
        HealBanksJob.perform_later
      end
    end
  end
end
