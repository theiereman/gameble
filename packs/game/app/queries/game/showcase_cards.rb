module Game
  module ShowcaseCards
    SIZE = 3

    def self.call(player, season:)
      return [] if player.nil? || season.nil?

      Holding.where(player_id: player.id).where("game_holdings.quantity > 0")
        .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id")
        .where(catalog_card_seasons: { season_id: season.id })
        .order(Arel.sql("catalog_card_seasons.rarity DESC, game_holdings.last_gained_at DESC NULLS LAST, game_holdings.card_season_id"))
        .limit(SIZE)
        .pluck(:card_season_id)
    end
  end
end
