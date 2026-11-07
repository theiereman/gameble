module Game
  module LibrarySyncedAt
    def self.call(player)
      CustomSet.steam_library.where(player_id: player.id).pick(:synced_at)
    end
  end
end
