module Catalog
  # Whether season rows hold a card imported before its sources were stored:
  # a genre that is no theme, or no review count. Published, such a card
  # lands in the UFOs and never counts toward a franchise, studio or hall of
  # fame set; Catalog::FillCardSources fills it.
  module UnfilledSources
    def self.any?(rows)
      rows.any? { |row| row.review_count.nil? || row.genres.any? { |genre| !Themes.key?(genre) } }
    end
  end
end
