module Game
  class DeckCard < ApplicationRecord
    self.table_name = "game_deck_cards"

    belongs_to :deck, class_name: "Game::Deck", inverse_of: :cards
  end
end
