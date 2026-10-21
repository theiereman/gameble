module Catalog
  # Published when a card's season scores are staged in a batch.
  # Identifiers only: data = { batch_token:, card_id: }, on the batch's stream.
  class CardSeasonStaged < RubyEventStore::Event
  end
end
