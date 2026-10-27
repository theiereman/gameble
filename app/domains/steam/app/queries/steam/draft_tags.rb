module Steam
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
