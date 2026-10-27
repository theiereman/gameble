module Catalog
  # The themes a card can belong to, each grouping the Steam tags attached to
  # it by the administrators (TagClassification), by tag key (TagKey); a
  # theme's names are stored (Theme). A game joins every theme one of its
  # TOP_TAGS most-voted tags belongs to; a game with none joins the UFOs. The
  # first theme in vote order is the card's main theme, shown as its genre.
  #
  # The classification is read once (`classification`) and passed along, so
  # a run or a page never queries per game.
  #
  #   classification = Catalog::Themes.classification
  #   Catalog::Themes.of([ "indie", "roguelite", "deckbuilding", "horror" ], classification)
  #   # => ["roguelike", "deckbuilder", "horror"]
  module Themes
    # The share of a season's cards the UFOs may not exceed.
    UFO_SHARE_LIMIT = 0.05
    # A game's themes come from this many of its most-voted tags.
    TOP_TAGS = 5

    # `theme_by_tag` is { tag key => theme key }, `dismissed` the tag keys
    # that are no theme.
    Classification = Data.define(:theme_by_tag, :dismissed) do
      def theme_keys = theme_by_tag.values.uniq

      def classified?(tag_key) = theme_by_tag.key?(tag_key) || dismissed.include?(tag_key)

      # The themes of `tag_keys`' first TOP_TAGS, in the tags' order, each
      # once; a tag of no theme is skipped.
      def themes_of(tag_keys)
        tag_keys.first(TOP_TAGS).filter_map { |tag_key| theme_by_tag[tag_key] }.uniq
      end

      # { tag key => number of rows } of the tags the rows carry among their
      # most-voted and that nobody classified yet.
      def unclassified_in(rows)
        rows.flat_map { |row| row.tags.first(TOP_TAGS).uniq }.reject { |tag_key| classified?(tag_key) }.tally
      end

      # Whether some row's genres differ from what the classification gives
      # its tags now: the draft needs a rescore.
      def stale?(rows)
        rows.any? { |row| themes_of(row.tags) != row.genres }
      end
    end

    # The theme keys, in the order the themes were created: the seeded list
    # first, then the themes administrators added.
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

    # Whether `ufo_count` of `card_count` cards is above UFO_SHARE_LIMIT.
    def self.ufo_share_over_limit?(ufo_count, card_count)
      card_count.positive? && ufo_count.fdiv(card_count) > UFO_SHARE_LIMIT
    end

    def self.of(tag_keys, classification = self.classification)
      classification.themes_of(tag_keys)
    end
  end
end
