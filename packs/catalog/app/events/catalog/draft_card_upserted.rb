module Catalog
  # Published on every write of a card into the draft season, even when
  # nothing changed (AD-10). Identifiers only:
  # data = { card_id:, season_id:, card_season_id: }, on the season's stream.
  class DraftCardUpserted < RubyEventStore::Event
  end
end
