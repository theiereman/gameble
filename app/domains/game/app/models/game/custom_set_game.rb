module Game
  class CustomSetGame < ApplicationRecord
    self.table_name = "game_custom_set_games"

    belongs_to :custom_set, class_name: "Game::CustomSet", inverse_of: :games
  end
end
