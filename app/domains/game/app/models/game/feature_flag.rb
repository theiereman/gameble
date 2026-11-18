module Game
  class FeatureFlag < ApplicationRecord
    self.table_name = "game_feature_flags"

    KEYS = %w[duels].freeze

    validates :key, inclusion: { in: KEYS }
  end
end
