module Game
  module Handlers
    module GoalsReached
      PLAYERS = {
        Game::PackOpened => [ :player_id ],
        Game::TradeAccepted => [ :proposer_id, :recipient_id ],
        Game::CustomSetEdited => [ :player_id ],
        Game::Market::AuctionSold => [ :winner_id ],
        Game::Market::OrderServed => [ :buyer_id ],
        Game::Market::WantedChoicesApplied => Game::Market::WantedChoicesApplied.method(:buyer_ids),
        Game::Market::ArchivePurchased => [ :player_id ]
      }.freeze
      EVENTS = PLAYERS.keys.freeze

      def self.call(event)
        Goal.drop_reached(NamedPlayers.of(event, PLAYERS))
      end
    end
  end
end
