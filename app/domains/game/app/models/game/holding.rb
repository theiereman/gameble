module Game
  # A player's copies of one card-season (AD-6): a count, never a row per
  # copy. `reserved` is the part promised to open trades; the database keeps
  # `quantity >= reserved >= 0`. One row per player and card-season.
  #
  # `last_gained_at` is when the quantity last rose (AD-26), set by every
  # operation that raises it (today Game::OpenPack's credit) and by nothing
  # that only moves `reserved`; NULL for the holdings gained before it
  # existed, which are never new. A holding with copies gained after the
  # player's watermark (Game::PlayerState#collection_seen_up_to) is new:
  # Game::CollectionSlots reads it.
  #
  # No association to Catalog (see Game::Pack). Written only through the
  # operations of this pack (AD-3).
  class Holding < ApplicationRecord
    self.table_name = "game_holdings"
  end
end
