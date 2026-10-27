module Catalog
  module PublishedCardSeasonIds
    def self.call(pairs)
      wanted = pairs.to_set { |slug, season_number| [ slug.to_s, season_number ] }
      return {} if wanted.empty?

      CardSeason.where.not(rarity: nil).joins(:card, :season)
        .where(catalog_cards: { slug: wanted.map(&:first).uniq },
          catalog_seasons: { status: "published", number: wanted.map(&:last).uniq })
        .pluck("catalog_cards.slug", "catalog_seasons.number", "catalog_card_seasons.id")
        .each_with_object({}) { |(slug, number, id), ids| ids[[ slug, number ]] = id if wanted.include?([ slug, number ]) }
    end
  end
end
