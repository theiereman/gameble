module Game
  class DuelSeat < ApplicationRecord
    self.table_name = "game_duel_seats"

    belongs_to :duel, class_name: "Game::Duel", inverse_of: :seats
  end
end
