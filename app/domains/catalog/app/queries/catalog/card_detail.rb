module Catalog
  module CardDetail
    Detail = Data.define(:view, :short_description, :publisher, :store_url, :steam_reviews, :sets, :card_season_id, :card_id, :current_season)

    SteamReviews = Data.define(:count, :positive_percent)

    LATEST = "(SELECT MAX(published.number) FROM catalog_seasons published WHERE published.status = 'published')".freeze

    COLUMNS = [
      "catalog_card_seasons.id", "catalog_cards.slug", "catalog_card_texts.title", "catalog_card_texts.short_description",
      "catalog_cards.publisher", "catalog_cards.store_url", "catalog_cards.release_date",
      "catalog_seasons.number", "catalog_card_seasons.rarity", "catalog_cards.image_url",
      "catalog_seasons.number = #{LATEST}", "catalog_card_seasons.number", CardViews::GENRE,
      "catalog_card_seasons.review_count", "catalog_card_seasons.rating", "catalog_card_seasons.card_id"
    ].freeze

    def self.call(slug:, locale:, season_number: nil)
      row = card_season(slug.to_s, locale.to_s, season_number)
      return if row.nil?

      id, slug, title, description, publisher, store_url, release_date, season_number, rarity, image_url, current,
        number, genre, review_count, rating, card_id = row
      view = CardView.new(id: slug, title:, publisher:, year: release_date.year, season_number:,
        rarity:, image_url:, number:, genre:)
      steam_reviews = review_count && SteamReviews.new(count: review_count, positive_percent: rating)
      Detail.new(view:, short_description: description.presence, publisher:, store_url:, steam_reviews:,
        sets: sets(id, main_theme: genre), card_season_id: id, card_id:, current_season: current)
    end

    def self.card_season(slug, locale, season_number)
      scope = CardSeason.where.not(rarity: nil)
        .joins(:card, :season)
        .joins("JOIN catalog_card_texts ON catalog_card_texts.card_id = catalog_card_seasons.card_id")
        .where(catalog_cards: { slug: }, catalog_card_texts: { locale: }, catalog_seasons: { status: "published" })
      scope = season_number.nil? ? scope.where(Arel.sql("catalog_seasons.number = #{LATEST}")) : scope.where(catalog_seasons: { number: season_number })
      scope.pick(*COLUMNS.map { |column| Arel.sql(column) })
    end
    private_class_method :card_season

    def self.sets(card_season_id, main_theme:)
      Set.joins(:memberships).where(catalog_set_memberships: { card_season_id: })
        .order(SetKind::ORDER, SeasonSets::HALL_OF_FAME_ORDER, :key)
        .pluck(:kind, :key, :params)
        .map { |kind, key, params| SetRef.new(kind:, key:, params:) }
        .partition { |set| set.kind == "theme" && set.key == main_theme }.flatten
    end
    private_class_method :sets
  end
end
