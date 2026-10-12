module Catalog
  # Published once per call of Catalog::FillCardSources, even when nothing
  # was filled. Counts only: data = { cards:, card_seasons: }, the rows
  # filled, on the stream Catalog::FillCardSources::STREAM.
  class CardSourcesFilled < RubyEventStore::Event
  end
end
