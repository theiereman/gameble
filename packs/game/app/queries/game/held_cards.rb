module Game
  module HeldCards
    def self.relation(player)
      Holding.joins("JOIN catalog_card_seasons AS held_editions ON held_editions.id = game_holdings.card_season_id")
        .where(player_id: player.id)
        .where("game_holdings.quantity > 0")
        .select("held_editions.card_id")
    end
  end
end
