module Game
  class ReactionNotice < ApplicationRecord
    self.table_name = "game_reaction_notices"

    belongs_to :feed_entry, class_name: "Game::FeedEntry"
  end
end
