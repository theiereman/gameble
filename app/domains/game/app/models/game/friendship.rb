module Game
  class Friendship < ApplicationRecord
    self.table_name = "game_friendships"

    scope :of, ->(player_id) { where(low_player_id: player_id).or(where(high_player_id: player_id)) }

    def self.other_ids(player_id)
      of(player_id).pluck(:low_player_id, :high_player_id).flatten.uniq - [ player_id ]
    end
  end
end
