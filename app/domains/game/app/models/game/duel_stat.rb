module Game
  # A card-season's duel profile: five stats ranked toward their first direction, rebuilt whole by Game::ComputeDuelStats.
  class DuelStat < ApplicationRecord
    self.table_name = "game_duel_stats"

    STATS = %i[popularity rating release discovery circulation].freeze
    DIRECTIONS = %w[high low].freeze
    REASONS = %w[first season weekly].freeze
  end
end
