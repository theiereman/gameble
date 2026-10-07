module Game
  # A friendship (AD-8): one row per pair, the lower player id first, unique;
  # it exists once an invitation is accepted. Written only through the
  # operations of this pack (AD-3).
  class Friendship < ApplicationRecord
    self.table_name = "game_friendships"

    # The friendships of a player, on whichever side of the pair.
    scope :of, ->(player_id) { where(low_player_id: player_id).or(where(high_player_id: player_id)) }
  end
end
