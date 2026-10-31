module Catalog
  module PublishedCardIds
    def self.call(source_keys:)
      keys = source_keys.map(&:to_s).uniq
      return [] if keys.empty?

      published_cards.where(source_key: keys).order(:id).pluck(:id)
    end

    def self.within(card_ids)
      ids = card_ids.grep(Integer).uniq
      return [] if ids.empty?

      published_cards.where(id: ids).order(:id).pluck(:id)
    end

    def self.by_slug(slugs)
      slugs = slugs.grep(String).uniq
      return {} if slugs.empty?

      published_cards.where(slug: slugs).pluck(:slug, :id).to_h
    end

    def self.published_cards
      Card.where(id: CardSeason.where.not(rarity: nil).joins(:season).where(catalog_seasons: { status: "published" }).select(:card_id))
    end
    private_class_method :published_cards
  end
end
