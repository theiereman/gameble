module Game
  module OpenedPackByToken
    def self.call(player, token)
      return nil if player.nil? || !token.is_a?(String) || token.blank?

      Pack.where(player_id: player.id, token:).where.not(opened_at: nil).take
    end
  end
end
