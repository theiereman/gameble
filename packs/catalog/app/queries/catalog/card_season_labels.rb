module Catalog
  # What a list of drawn cards shows (CAP-4): each card-season's title in a
  # locale and its rarity tier name (Rarity::TIERS), in one query.
  #
  #   Catalog::CardSeasonLabels.call([ 12, 7 ], locale: "fr")
  #   # => { 12 => { title: "Portal", rarity: :amethyst }, 7 => { … } }
  module CardSeasonLabels
    def self.call(ids, locale:)
      return {} if ids.empty?

      CardSeason.where(id: ids.uniq)
        .joins("JOIN catalog_card_texts ON catalog_card_texts.card_id = catalog_card_seasons.card_id")
        .where(catalog_card_texts: { locale: locale.to_s })
        .pluck(:id, "catalog_card_texts.title", :rarity)
        .to_h { |id, title, rarity| [ id, { title:, rarity: rarity&.to_sym } ] }
    end
  end
end
