module Catalog
  # The CardViews of card-seasons, in one query: title in a locale, publisher,
  # release year and art of the card, rarity, number and tome genre of the
  # card-season, number of its season. A card-season without rarity (a
  # draft) is left out, as is an unknown id.
  #
  #   Catalog::CardViews.call([ 12, 7 ], locale: "fr")
  #   # => { 12 => CardView(title: "Portal", rarity: "epic", …), 7 => … }
  module CardViews
    # The genre of the card-season's tome (its sets are those of its season),
    # nil when it is in no tome; a card-season sits in one tome at most.
    GENRE = "(SELECT tome.params->>'genre' FROM catalog_set_memberships membership " \
      "JOIN catalog_sets tome ON tome.id = membership.set_id " \
      "WHERE membership.card_season_id = catalog_card_seasons.id AND tome.kind = 'tome' LIMIT 1)".freeze

    COLUMNS = [
      "catalog_card_seasons.id", "catalog_cards.slug", "catalog_card_texts.title", "catalog_cards.publisher",
      "catalog_cards.release_date", "catalog_seasons.number", "catalog_card_seasons.rarity",
      "catalog_cards.image_url", "catalog_card_seasons.number", GENRE
    ].freeze

    # The rarity enum comes back as its name ("rare").
    def self.call(card_season_ids, locale:)
      return {} if card_season_ids.empty?

      CardSeason.where(id: card_season_ids.uniq)
        .where.not(rarity: nil)
        .joins(:card, :season)
        .joins("JOIN catalog_card_texts ON catalog_card_texts.card_id = catalog_card_seasons.card_id")
        .where(catalog_card_texts: { locale: locale.to_s })
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
        .to_h do |id, slug, title, publisher, release_date, season_number, rarity, image_url, number, genre|
          [ id, CardView.new(id: slug, title:, publisher:, year: release_date.year, season_number:,
            rarity:, image_url:, number:, genre:) ]
        end
    end
  end
end
