module Catalog
  module PublishedCardSeasonsByTier
    def self.call(season = PublishedSeason.call)
      return nil if season.nil?

      tiers = Rarity::TIERS.keys.index_with { [] }
      CardSeason.where(season_id: season.id).order(:id).pluck(:rarity, :id).each do |rarity, id|
        tiers.fetch(CardSeason.rarities.fetch(rarity)) << id
      end
      { season_id: season.id, tiers: }
    end
  end
end
