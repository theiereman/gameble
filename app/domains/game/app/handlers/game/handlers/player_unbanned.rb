module Game
  module Handlers
    module PlayerUnbanned
      def self.call(event)
        Market::RefreshWantedJob.perform_later(event.data.fetch(:player_id))
      end
    end
  end
end
