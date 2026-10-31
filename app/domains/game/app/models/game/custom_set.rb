module Game
  class CustomSet < ApplicationRecord
    self.table_name = "game_custom_sets"

    CUSTOM = "custom"
    STEAM_LIBRARY = "steam_library"

    NAME_LIMIT = 40
    GAMES = (3..50)
    PER_PLAYER = 10

    has_secure_token :token, length: 24

    has_many :games, class_name: "Game::CustomSetGame", inverse_of: :custom_set

    enum :kind, { custom: CUSTOM, steam_library: STEAM_LIBRARY }, validate: true

    def self.named(name)
      where("lower(name) = lower(?)", name)
    end
  end
end
