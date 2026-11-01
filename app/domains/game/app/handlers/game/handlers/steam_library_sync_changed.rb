module Game
  module Handlers
    module SteamLibrarySyncChanged
      def self.call(event)
        return if event.data.fetch(:enabled)

        player = Accounts::PlayerById.call(event.data.fetch(:player_id))
        EraseLibrarySet.new.call(player:).value!
      end
    end
  end
end
