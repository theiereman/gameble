module Game
  class DuelStat < ApplicationRecord
    self.table_name = "game_duel_stats"

    STATS = %i[popularity rating release discovery circulation].freeze
    DIRECTIONS = %i[high low].freeze
    CALLS = STATS.product(DIRECTIONS).freeze
    REASONS = %w[first season weekly].freeze
  end
end
