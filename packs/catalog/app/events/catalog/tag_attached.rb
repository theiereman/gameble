module Catalog
  # Published when an administrator attaches a Steam tag to an existing theme. Identifiers only: data = { theme_id:, tag_key: }, on the themes' stream.
  class TagAttached < RubyEventStore::Event
  end
end
