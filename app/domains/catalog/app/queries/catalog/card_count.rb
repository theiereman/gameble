module Catalog
  module CardCount
    def self.call(season)
      return 0 if season.nil?

      CardSeason.where(season_id: season.id).where.not(rarity: nil).count
    end
  end
end
