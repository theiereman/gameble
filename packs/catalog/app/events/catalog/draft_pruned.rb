module Catalog
  # Published when the draft season is pruned down to a pass's cards
  # (Catalog::PruneDraft, AD-10), even when nothing was removed. Identifiers
  # and a count only: data = { season_id:, removed: }, on the season's stream.
  class DraftPruned < RubyEventStore::Event
  end
end
