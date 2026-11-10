module Game
  module Market
    # The copies of one edition the Archives keep: a derived sum of the deposits, which no per-player write touches.
    class ArchiveStock < ApplicationRecord
      self.table_name = "game_market_archive_stocks"
    end
  end
end
