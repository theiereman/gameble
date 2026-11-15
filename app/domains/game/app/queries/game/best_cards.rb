module Game
  module BestCards
    def self.call(player, limit:, except: [])
      return [] if player.nil? || limit <= 0

      Holding.where(player_id: player.id).where("game_holdings.quantity > 0")
        .where.not(card_season_id: except)
        .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id")
        .order(Arel.sql("catalog_card_seasons.rarity DESC, game_holdings.last_gained_at DESC NULLS LAST, game_holdings.card_season_id"))
        .limit(limit)
        .pluck(:card_season_id)
    end
  end
end
