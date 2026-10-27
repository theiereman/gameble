module Catalog
  # Published when an administrator marks Steam tags as no theme. Identifiers only: data = { tag_keys: }, on the themes' stream.
  class TagsDismissed < RubyEventStore::Event
  end
end
