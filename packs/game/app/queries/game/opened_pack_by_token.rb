module Game
  # A player's opened pack by its token (AD-15), or nil: a pack of another
  # player, one not opened yet, or an unknown token.
  module OpenedPackByToken
    def self.call(player, token)
      return nil if player.nil? || !token.is_a?(String) || token.blank?

      Pack.where(player_id: player.id, token:).where.not(opened_at: nil).take
    end
  end
end
