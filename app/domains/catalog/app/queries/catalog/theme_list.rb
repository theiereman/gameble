module Catalog
  module ThemeList
    Entry = Data.define(:theme, :tag_count)

    def self.call
      counts = TagClassification.where.not(theme_id: nil).group(:theme_id).count
      Theme.all.sort_by { |theme| [ theme.name_en.downcase, theme.id ] }.map { |theme| Entry.new(theme:, tag_count: counts.fetch(theme.id, 0)) }
    end
  end
end
