module Game
  # A player's copies of one card-season (AD-6): a count, never a row per
  # copy. `reserved` is the part promised to open trades; the database keeps
  # `quantity >= reserved >= 0`. One row per player and card-season.
  #
  # No association to Catalog (see Game::Pack). Written only through the
  # operations of this pack (AD-3).
  class Holding < ApplicationRecord
    self.table_name = "game_holdings"
  end
end
