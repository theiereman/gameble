module Catalog
  # The rarity tier (Rarity::TIERS integer) of each card-season asked about,
  # in one query; a card-season without rarity (a draft) or an unknown id is
  # left out.
  #
  #   Catalog::CardSeasonTiers.call([ 12, 7 ]) # => { 12 => 3, 7 => 1 }
  module CardSeasonTiers
    def self.call(card_season_ids)
      return {} if card_season_ids.empty?

      CardSeason.where(id: card_season_ids.uniq).where.not(rarity: nil).pluck(:id, :rarity)
        .to_h { |id, name| [ id, Rarity::TIERS.key(name.to_sym) ] }
    end
  end
end
