module Catalog
  # Published when an administrator creates a theme from a tag. Identifiers only: data = { theme_id:, tag_key: }, on the themes' stream.
  class ThemeCreated < RubyEventStore::Event
  end
end
