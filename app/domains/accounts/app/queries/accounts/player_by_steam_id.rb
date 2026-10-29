module Accounts
  module PlayerBySteamId
    def self.call(steam_id)
      steam_id = steam_id.to_s.strip
      return nil if steam_id.empty?

      Player.find_by(id: Identity.where(provider: "steam", uid: steam_id).select(:player_id), deleted_at: nil)
    end
  end
end
