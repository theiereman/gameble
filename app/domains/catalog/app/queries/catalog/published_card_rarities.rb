module Catalog
  # The rarities each card is published at, as symbols, keyed by card id.
  module PublishedCardRarities
    def self.call(card_ids)
      ids = Array(card_ids).uniq
      return {} if ids.empty?

      CardSeason.where(card_id: ids).where.not(rarity: nil).joins(:season).where(catalog_seasons: { status: "published" })
        .distinct.pluck(:card_id, :rarity)
        .each_with_object(Hash.new { |hash, key| hash[key] = [] }) { |(card_id, rarity), rarities| rarities[card_id] << rarity.to_sym }
    end
  end
end
