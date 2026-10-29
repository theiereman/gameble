module Accounts
  module CurrentBanReason
    def self.call(steam_id)
      return nil unless steam_id.is_a?(String)

      for_player(Player.where.not(banned_at: nil).find_by(id: Identity.where(provider: "steam", uid: steam_id).select(:player_id)))
    end

    def self.through_clerk(session_token)
      client = ClerkClient.new
      claims = client.verify_session(session_token)
      return nil if claims.failure?

      for_player(Player.where.not(banned_at: nil).find_by(id: Identity.where(clerk_user_id: claims.value!.fetch("sub")).select(:player_id)))
    end

    def self.for_player(player)
      return nil if player.nil?

      latest = ModerationAction.where(player:, kind: [ :ban, :unban ]).order(created_at: :desc, id: :desc).first
      latest.reason if latest&.ban?
    end
  end
end
