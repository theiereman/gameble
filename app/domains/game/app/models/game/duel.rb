module Game
  class Duel < ApplicationRecord
    self.table_name = "game_duels"

    has_secure_token :token, length: 24

    has_many :seats, class_name: "Game::DuelSeat", inverse_of: :duel, dependent: nil
    has_many :rounds, -> { order(:number) }, class_name: "Game::DuelRound", inverse_of: :duel, dependent: nil

    def started? = state == "active" || state == "finished"

    def cards(role) = (self[:"#{role}_cards"] || []).map { DuelCard.from_snapshot(it) }

    def draw_order(role) = self[:"#{role}_draw_order"] || []
  end
end
