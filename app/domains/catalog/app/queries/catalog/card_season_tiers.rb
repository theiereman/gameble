module Catalog
  module CardSeasonTiers
    def self.call(card_season_ids)
      return {} if card_season_ids.empty?

      CardSeason.where(id: card_season_ids.uniq).where.not(rarity: nil).pluck(:id, :rarity)
        .to_h { |id, name| [ id, Rarity::TIERS.key(name.to_sym) ] }
    end
  end
end
