module Accounts
  module SteamIdOf
    def self.call(player)
      return nil if player&.id.nil?

      Identity.where(player_id: player.id, provider: "steam").pick(:uid)
    end
  end
end
