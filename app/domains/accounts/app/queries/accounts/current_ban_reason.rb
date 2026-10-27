module Accounts
  module CurrentBanReason
    def self.call(steam_id)
      return nil unless steam_id.is_a?(String)

      player = Player.where.not(banned_at: nil).find_by(steam_id:)
      return nil if player.nil?

      latest = ModerationAction.where(player:, kind: [ :ban, :unban ]).order(created_at: :desc, id: :desc).first
      latest.reason if latest&.ban?
    end
  end
end
