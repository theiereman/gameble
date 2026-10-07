module Game
  module Handlers
    # Cuts a banned player off from their friends and trades (R6, AD-14,
    # Game::DropFriendsAndTrades). Synchronously, inside the ban's
    # transaction (config/initializers/event_store.rb): a failure raises,
    # which rolls the ban back. Their cards stay theirs, released from the
    # trades.
    module PlayerBanned
      def self.call(event)
        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        DropFriendsAndTrades.new.call(player:).value!
      end
    end
  end
end
