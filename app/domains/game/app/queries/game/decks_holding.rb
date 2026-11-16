module Game
  module DecksHolding
    def self.call(player, card_season_ids = nil)
      return {} if player.nil? || card_season_ids&.empty?

      cards = DeckCard.of_player(player.id)
      cards = cards.where(card_season_id: card_season_ids) if card_season_ids
      cards.order("game_decks.created_at", "game_decks.id").pluck(:card_season_id, "game_decks.name")
        .each_with_object({}) { |(card_season_id, name), names| (names[card_season_id] ||= []) << name }
    end
  end
end
