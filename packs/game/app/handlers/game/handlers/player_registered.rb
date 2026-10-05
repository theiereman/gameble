module Game
  module Handlers
    # Fills a new player's bank (AD-7, AD-10), then creates their game state
    # row (Game::CreatePlayerState), in the lock order of AD-10: the bank
    # first, the state row last. Synchronously, inside the sign-up's
    # transaction (config/initializers/event_store.rb). A failure raises,
    # which rolls the sign-up back: a player is never created without a
    # state row, nor without a bank while a season is published.
    module PlayerRegistered
      def self.call(event)
        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        FillBank.new.call(player:).value!
        CreatePlayerState.new.call(player:).value!
      end
    end
  end
end
