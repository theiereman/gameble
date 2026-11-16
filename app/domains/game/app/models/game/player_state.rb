module Game
  class PlayerState < ApplicationRecord
    self.table_name = "game_player_states"

    def self.count_goals_completed(counts_by_player)
      counts_by_player.each do |player_id, count|
        insert({ player_id: }, unique_by: :player_id)
        where(player_id:).update_all([ "goals_completed = goals_completed + ?, updated_at = ?", count, Time.current ])
      end
    end

    def self.markers_at_published_season
      published = Catalog::PublishedSeason.call&.number
      { allocation_received_season: published, allocation_seen_season: published }
    end
  end
end
