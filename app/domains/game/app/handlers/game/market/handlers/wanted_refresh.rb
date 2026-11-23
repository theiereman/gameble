module Game
  module Market
    module Handlers
      module WantedRefresh
        PLAYERS = {
          Game::PackOpened => [ :player_id ],
          Game::TradeAccepted => [ :proposer_id, :recipient_id ],
          Game::Market::AuctionSold => [ :seller_id, :winner_id ],
          Game::Market::OrderServed => [ :buyer_id, :seller_id ],
          Game::Market::WantedChoicesApplied => Game::Market::WantedChoicesApplied.method(:player_ids),
          Game::Market::CardsEntrusted => [ :player_id ],
          Game::Market::ArchivePurchased => [ :player_id ],
          Game::GoalAdded => [ :player_id ],
          Game::GoalRemoved => [ :player_id ],
          Game::SlotBought => ->(data) { data.fetch(:goal_id) ? [ data.fetch(:player_id) ] : [] },
          Game::CustomSetEdited => [ :player_id ],
          Game::CustomSetDeleted => [ :player_id ],
          Game::LibrarySetSynced => [ :player_id ],
          Game::Market::OrderPlaced => [ :player_id ],
          Game::Market::OrderCancelled => [ :player_id ],
          Game::Market::OrderExpired => [ :player_id ],
          Game::Market::OrderWithdrawn => [ :player_id ]
        }.freeze
        EVENTS = PLAYERS.keys.freeze

        def self.call(event)
          players = Accounts::Player.in_good_standing.where(id: Game::Handlers::NamedPlayers.of(event, PLAYERS)).order(:id).pluck(:id)
          PendingWantedRefresh.mark(players).each { RefreshWantedJob.perform_later(it) }
        end
      end
    end
  end
end
