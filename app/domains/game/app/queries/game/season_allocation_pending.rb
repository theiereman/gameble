module Game
  module SeasonAllocationPending
    def self.call(player)
      return false if player.nil?

      unseen_with_history?(player)
    end

    def self.unseen_with_history?(player)
      season = Catalog::PublishedSeason.call
      return false if season.nil? || seen_season(player) >= season.number

      earlier_card_held?(player, season)
    end
    private_class_method :unseen_with_history?

    def self.seen_season(player)
      PlayerState.where(player_id: player.id).pick(:allocation_seen_season).to_i
    end
    private_class_method :seen_season

    def self.earlier_card_held?(player, season)
      Holding.where(player_id: player.id).where("game_holdings.quantity > 0")
        .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id " \
          "JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id")
        .exists?([ "catalog_seasons.number < ?", season.number ])
    end
    private_class_method :earlier_card_held?
  end
end
