module Game
  module Handlers
    module VisibilityChanged
      def self.call(event)
        return unless event.data.fetch(:visibility) == "private"

        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        CancelOpenTrades.new.call(player:).value!
      end
    end
  end
end
