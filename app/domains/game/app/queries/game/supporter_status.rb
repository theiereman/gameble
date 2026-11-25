module Game
  module SupporterStatus
    def self.call(player)
      PlayerState.where(player_id: player.id).where.not(supporter_at: nil).exists?
    end

    def self.for_players(players)
      ids = players.compact.map(&:id).uniq
      ids.empty? ? Set.new : PlayerState.where(player_id: ids).where.not(supporter_at: nil).pluck(:player_id).to_set
    end
  end
end
