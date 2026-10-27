module Game
  module Handlers
    module PlayerBanned
      def self.call(event)
        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        DropFriendsAndTrades.new.call(player:).value!
      end
    end
  end
end
