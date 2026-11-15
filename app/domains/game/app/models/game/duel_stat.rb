module Game
  class DuelStat < ApplicationRecord
    self.table_name = "game_duel_stats"

    STATS = %i[popularity rating release discovery circulation].freeze
    REASONS = %w[first season weekly].freeze
  end
end
