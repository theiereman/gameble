module Game
  module Handlers
    module GoalsReached
      EVENTS = [ Game::PackOpened, Game::TradeAccepted ].freeze

      def self.call(event)
        data = event.data
        Goal.drop_reached(event.is_a?(Game::TradeAccepted) ? data.values_at(:proposer_id, :recipient_id) : [ data.fetch(:player_id) ])
      end
    end
  end
end
