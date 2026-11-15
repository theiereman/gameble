module Game
  # The card-seasons the player's decks hold, leaving out the deck given.
  module DeckedEditions
    def self.call(player, except: nil)
      return Set.new if player.nil?

      decks = Deck.where(player_id: player.id)
      decks = decks.where.not(id: except.id) if except
      DeckCard.where(deck_id: decks.select(:id)).distinct.pluck(:card_season_id).to_set
    end
  end
end
