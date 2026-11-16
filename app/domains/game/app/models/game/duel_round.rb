module Game
  class DuelRound < ApplicationRecord
    self.table_name = "game_duel_rounds"

    belongs_to :duel, class_name: "Game::Duel", inverse_of: :rounds
  end
end
