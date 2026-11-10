module Game
  module Handlers
    module GoalsReached
      PLAYERS = {
        Game::PackOpened => [ :player_id ],
        Game::TradeAccepted => [ :proposer_id, :recipient_id ],
        Game::CustomSetEdited => [ :player_id ],
        Game::Market::AuctionSold => [ :winner_id ]
      }.freeze
      EVENTS = PLAYERS.keys.freeze

      def self.call(event)
        Goal.drop_reached(PLAYERS.fetch(event.class).map { event.data.fetch(it) })
      end
    end
  end
end
