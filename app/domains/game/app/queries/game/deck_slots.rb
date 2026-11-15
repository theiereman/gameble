module Game
  # A deck's filled slots: the card-season in each, by slot.
  module DeckSlots
    def self.call(deck)
      return {} if deck.nil?

      DeckCard.where(deck_id: deck.id).order(:slot).pluck(:slot, :card_season_id).to_h
    end
  end
end
