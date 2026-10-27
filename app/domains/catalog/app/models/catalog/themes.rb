module Catalog
  module Themes
    UFO_SHARE_LIMIT = 0.05
    TOP_TAGS = 5

    Classification = Data.define(:theme_by_tag, :dismissed) do
      def theme_keys = theme_by_tag.values.uniq

      def classified?(tag_key) = theme_by_tag.key?(tag_key) || dismissed.include?(tag_key)

      def themes_of(tag_keys)
        tag_keys.first(TOP_TAGS).filter_map { |tag_key| theme_by_tag[tag_key] }.uniq
      end

      def unclassified_in(rows)
        rows.flat_map { |row| row.tags.first(TOP_TAGS).uniq }.reject { |tag_key| classified?(tag_key) }.tally
      end

      def stale?(rows)
        rows.any? { |row| themes_of(row.tags) != row.genres }
      end
    end

    def self.keys
      Theme.order(:id).pluck(:key)
    end

    def self.classification
      pairs = TagClassification.left_joins(:theme).order(:id).pluck(:tag_key, "catalog_themes.key", :not_a_theme)
      Classification.new(
        theme_by_tag: pairs.reject { |_, _, dismissed| dismissed }.to_h { |tag_key, theme_key, _| [ tag_key, theme_key ] },
        dismissed: pairs.filter_map { |tag_key, _, dismissed| tag_key if dismissed }.to_set
      )
    end

    def self.ufo_share_over_limit?(ufo_count, card_count)
      card_count.positive? && ufo_count.fdiv(card_count) > UFO_SHARE_LIMIT
    end

    def self.of(tag_keys, classification = self.classification)
      classification.themes_of(tag_keys)
    end
  end
end
