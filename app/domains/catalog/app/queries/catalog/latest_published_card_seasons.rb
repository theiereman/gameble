module Catalog
  module LatestPublishedCardSeasons
    LATEST_FIRST = "catalog_card_seasons.card_id, catalog_seasons.number DESC".freeze

    def self.call(card_ids)
      ids = card_ids.uniq
      return {} if ids.empty?

      published.where(card_id: ids).order(Arel.sql(LATEST_FIRST))
        .pluck(Arel.sql("DISTINCT ON (catalog_card_seasons.card_id) catalog_card_seasons.card_id"), Arel.sql("catalog_card_seasons.id"))
        .to_h
    end

    def self.rarities
      published.order(Arel.sql(LATEST_FIRST))
        .select(Arel.sql("DISTINCT ON (catalog_card_seasons.card_id) catalog_card_seasons.card_id, catalog_card_seasons.rarity"))
    end

    def self.faces(query: nil, locale: I18n.locale, picked: nil)
      latest = published.order(Arel.sql(LATEST_FIRST)).select(Arel.sql("DISTINCT ON (catalog_card_seasons.card_id) catalog_card_seasons.id"))
      latest = latest.where(card_id: picked) if picked
      faces = CardSeason.where(id: latest).joins(:season)
      text = query.to_s.strip.first(CollectionGrid::MAX_QUERY)
      faces = faces.where(CollectionGrid.text_match(text, locale)) if text.present?
      picked ? faces.in_order_of(:card_id, picked) : faces.order(Arel.sql("catalog_seasons.number DESC"), :number, :id)
    end

    def self.published
      CardSeason.where.not(rarity: nil).joins(:season).where(catalog_seasons: { status: "published" })
    end
    private_class_method :published
  end
end
