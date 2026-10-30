module Catalog
  module ShareImagesOfCard
    Stored = Data.define(:card_season_id, :locale, :fingerprint)

    def self.call(card_id)
      ShareImage.joins(:card_season).where(catalog_card_seasons: { card_id: })
        .pluck(:card_season_id, :locale, :fingerprint)
        .map { |card_season_id, locale, fingerprint| Stored.new(card_season_id:, locale:, fingerprint:) }
    end
  end
end
