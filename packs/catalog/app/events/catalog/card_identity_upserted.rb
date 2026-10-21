module Catalog
  # Published on every write of a card's identity, even when nothing changed.
  # Identifiers only: data = { card_id: }, on the card's stream.
  class CardIdentityUpserted < RubyEventStore::Event
  end
end
