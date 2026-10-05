module Catalog
  # How many cards a season holds (the total of the hub's collection meta,
  # "87/16 480"): its card-seasons with a rarity, the ones publishing kept.
  # One query; 0, without a query, for no season.
  #
  #   Catalog::CardCount.call(season) # => 16480
  module CardCount
    def self.call(season)
      return 0 if season.nil?

      CardSeason.where(season_id: season.id).where.not(rarity: nil).count
    end
  end
end
