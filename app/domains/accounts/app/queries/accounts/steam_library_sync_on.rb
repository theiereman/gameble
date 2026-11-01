module Accounts
  module SteamLibrarySyncOn
    def self.call(player)
      return false if player&.id.nil?

      Player.where(id: player.id).pick(:steam_library_sync) == true
    end
  end
end
