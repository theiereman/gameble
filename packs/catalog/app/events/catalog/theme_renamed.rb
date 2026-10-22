module Catalog
  # Published when an administrator renames a theme. Identifiers only: data = { theme_id: }, on the themes' stream.
  class ThemeRenamed < RubyEventStore::Event
  end
end
