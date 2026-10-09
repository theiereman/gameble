module Game
  module Handlers
    module PlayerRegistered
      def self.call(event)
        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        FillBank.new.call(player:).value!
        CreatePlayerState.new.call(player:).value!
        CreateFriendCode.new.call(player:).value!
      end
    end
  end
end
