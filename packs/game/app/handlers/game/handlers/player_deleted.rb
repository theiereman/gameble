module Game
  module Handlers
    # Releases what a deleted player holds (AD-14, Game::ReleasePlayer).
    # Synchronously, inside the deletion's transaction
    # (config/initializers/event_store.rb): a failure raises, which rolls the
    # deletion back, so an account is never deleted with its game left
    # behind.
    module PlayerDeleted
      def self.call(event)
        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        ReleasePlayer.new.call(player:).value!
      end
    end
  end
end
