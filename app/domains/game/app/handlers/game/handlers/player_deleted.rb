module Game
  module Handlers
    module PlayerDeleted
      def self.call(event)
        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        ReleasePlayer.new.call(player:).value!
      end
    end
  end
end
