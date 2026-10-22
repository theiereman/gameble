module Steam
  # The Steam tags the draft season's cards carry among their most-voted,
  # each with its English name and the number of games (cards) that carry it,
  # the most carried first. A tag whose name Steam no longer lists is named
  # after its key.
  #
  #   Steam::DraftTags.call # => [Steam::DraftTags::Entry(key: "roguelite", name: "Roguelite", game_count: 97), …]
  module DraftTags
    Entry = Data.define(:key, :name, :game_count)

    def self.call
      usage = Catalog::DraftTagUsage.call
      return [] if usage.empty?

      names = Tag.pluck(:name).index_by { |name| Catalog::TagKey.of(name) }
      usage.map { |key, game_count| Entry.new(key:, name: names.fetch(key) { key.humanize }, game_count:) }
    end
  end
end
