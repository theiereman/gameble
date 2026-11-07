module Game
  class FeedReaction < ApplicationRecord
    self.table_name = "game_feed_reactions"

    KINDS = %w[thumb heart gg wow middle_finger].freeze

    belongs_to :feed_entry, class_name: "Game::FeedEntry"
  end
end
