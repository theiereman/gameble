module Game
  module FirstCopies
    def self.call(player, pack)
      return Array.new(pack.card_season_ids.size, false) if player.nil? || !pack.opened?

      first_received = Holding.where(player_id: player.id, card_season_id: pack.card_season_ids.uniq, created_at: pack.opened_at)
        .pluck(:card_season_id).to_set
      pack.card_season_ids.map { |id| !first_received.delete?(id).nil? }
    end
  end
end
