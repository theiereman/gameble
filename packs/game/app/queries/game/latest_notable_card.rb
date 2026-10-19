module Game
  # The hub showcase's card: the Epic-or-better card the player still holds that they gained last.
  module LatestNotableCard
    LOWEST_TIER = Catalog::Rarity::TIERS.key(:epic)

    def self.call(player, season:)
      return if player.nil? || season.nil?

      Holding.where(player_id: player.id).where("game_holdings.quantity > 0")
        .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id")
        .where(catalog_card_seasons: { season_id: season.id })
        .where("catalog_card_seasons.rarity >= ?", LOWEST_TIER)
        .order(Arel.sql("game_holdings.last_gained_at DESC NULLS LAST, catalog_card_seasons.rarity DESC, game_holdings.card_season_id"))
        .pick(:card_season_id)
    end
  end
end
