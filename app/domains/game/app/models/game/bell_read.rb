module Game
  # A line of the bell the player has read on any device, by its key.
  class BellRead < ApplicationRecord
    self.table_name = "game_bell_reads"

    KEPT_PER_PLAYER = 200
    GROUPED_WANTED_KEY = "wanted:grouped"
  end
end
