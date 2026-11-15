module Game
  # The names of the player's decks holding each edition, oldest deck first; every decked edition when none is asked.
  module DecksHolding
    def self.call(player, card_season_ids = nil)
      return {} if player.nil? || card_season_ids&.empty?

      cards = DeckCard.joins(:deck).where(game_decks: { player_id: player.id })
      cards = cards.where(card_season_id: card_season_ids) if card_season_ids
      cards.order("game_decks.created_at", "game_decks.id").pluck(:card_season_id, "game_decks.name")
        .each_with_object({}) { |(card_season_id, name), names| (names[card_season_id] ||= []) << name }
    end
  end
end
