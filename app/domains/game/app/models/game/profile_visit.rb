module Game
  # One view of a player's public profile by another signed-in player.
  class ProfileVisit < ApplicationRecord
    self.table_name = "game_profile_visits"
  end
end
