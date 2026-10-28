module Game
  class PlayerState < ApplicationRecord
    self.table_name = "game_player_states"

    def self.markers_at_published_season
      published = Catalog::PublishedSeason.call&.number
      { allocation_received_season: published, allocation_seen_season: published }
    end
  end
end
