module Game
  class Deck < ApplicationRecord
    self.table_name = "game_decks"

    NAME_LIMIT = 24
    SLOTS = (1..12)

    has_secure_token :token, length: 24

    has_many :cards, class_name: "Game::DeckCard", inverse_of: :deck

    def self.named(name)
      where("lower(name) = lower(?)", name)
    end
  end
end
