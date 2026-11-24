module Game
  module SupporterStatus
    def self.call(player)
      PlayerState.where(player_id: player.id).where.not(supporter_at: nil).exists?
    end
  end
end
