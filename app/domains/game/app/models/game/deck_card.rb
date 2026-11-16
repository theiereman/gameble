module Game
  class DeckCard < ApplicationRecord
    self.table_name = "game_deck_cards"

    belongs_to :deck, class_name: "Game::Deck", inverse_of: :cards

    def self.of_player(player_id) = joins(:deck).where(game_decks: { player_id: })
  end
end
