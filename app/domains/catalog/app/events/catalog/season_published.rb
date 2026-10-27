module Catalog
  # Published when a season is published and becomes the one drawn from
  # (AD-5, AD-10). Identifiers only: data = { season_id: }, on the season's
  # stream.
  class SeasonPublished < RubyEventStore::Event
  end
end
