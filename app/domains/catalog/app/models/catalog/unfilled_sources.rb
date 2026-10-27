module Catalog
  module UnfilledSources
    def self.any?(rows, theme_keys: Themes.keys)
      listed = theme_keys.to_set
      rows.any? { |row| row.review_count.nil? || row.genres.any? { |genre| listed.exclude?(genre) } }
    end
  end
end
