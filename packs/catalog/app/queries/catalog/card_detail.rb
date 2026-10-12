module Catalog
  # A card's detail (CAP-7): its CardView in one card-season, with what only
  # the detail shows (the short description, the store link) and
  # the sets of that season holding it. The card is found by its slug alone
  # (AD-15: never by id, never through FriendlyId's fallback to the primary
  # key); the card-season is that of the season numbered `season_number`, or
  # of the published season without one. Only a published season is read;
  # an unknown slug, a season not published, a card absent from the season
  # or a card without text in the locale is nil.
  #
  # Two queries: the card, its text, card-season and season (the published
  # season folded in as a subquery); then its sets, the main theme's first,
  # the others in the library's tab order (theme, franchise, studio,
  # hall_of_fame, ufo, then the retired tome, publisher, best_of_year), the
  # hall of fame in its fixed order, the others by key.
  #
  #   Catalog::CardDetail.call(slug: "portal", locale: "fr")
  #   # => Detail(view: CardView(…), short_description: "…", sets: [ SetRef(…) ], current_season: true, …) | nil
  #
  # `card_season_id` is for the server's own joins (the viewer's copies); it
  # never reaches a page. `current_season` is true when the card-season is
  # the published season's.
  module CardDetail
    Detail = Data.define(:view, :short_description, :publisher, :store_url, :sets, :card_season_id, :current_season)

    LATEST = "(SELECT MAX(published.number) FROM catalog_seasons published WHERE published.status = 'published')".freeze

    COLUMNS = [
      "catalog_card_seasons.id", "catalog_cards.slug", "catalog_card_texts.title", "catalog_card_texts.short_description",
      "catalog_cards.publisher", "catalog_cards.store_url", "catalog_cards.release_date",
      "catalog_seasons.number", "catalog_card_seasons.rarity", "catalog_cards.image_url",
      "catalog_seasons.number = #{LATEST}", "catalog_card_seasons.number", CardViews::GENRE
    ].freeze

    KIND_ORDER = Arel.sql("CASE catalog_sets.kind WHEN 'theme' THEN 0 WHEN 'franchise' THEN 1 WHEN 'studio' THEN 2 " \
      "WHEN 'hall_of_fame' THEN 3 WHEN 'ufo' THEN 4 WHEN 'tome' THEN 5 WHEN 'publisher' THEN 6 WHEN 'best_of_year' THEN 7 ELSE 8 END")

    def self.call(slug:, locale:, season_number: nil)
      row = card_season(slug.to_s, locale.to_s, season_number)
      return if row.nil?

      id, slug, title, description, publisher, store_url, release_date, season_number, rarity, image_url, current,
        number, genre = row
      view = CardView.new(id: slug, title:, publisher:, year: release_date.year, season_number:,
        rarity:, image_url:, number:, genre:)
      Detail.new(view:, short_description: description.presence, publisher:, store_url:,
        sets: sets(id, main_theme: genre), card_season_id: id, current_season: current)
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

    # The set of the main theme first, then the others in KIND_ORDER.
    def self.sets(card_season_id, main_theme:)
      Set.joins(:memberships).where(catalog_set_memberships: { card_season_id: })
        .order(KIND_ORDER, SeasonShelf::HALL_OF_FAME_ORDER, :key)
        .pluck(:kind, :key, :params)
        .map { |kind, key, params| SetSlots::SetRef.new(kind:, key:, params:) }
        .partition { |set| set.kind == "theme" && set.key == main_theme }.flatten
    end
    private_class_method :sets
  end
end
