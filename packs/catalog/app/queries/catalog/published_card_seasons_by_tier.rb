module Catalog
  # The card-seasons of the published season by rarity tier, for the draw
  # (AD-5, AD-7): { season_id:, tiers: { 1 => [ids], …, 5 => [ids] } }, all
  # five tiers present; nil when no season is published. Reads on the
  # current connection: the draw runs inside a write transaction.
  module PublishedCardSeasonsByTier
    def self.call
      season = PublishedSeason.call
      return nil if season.nil?

      tiers = Rarity::TIERS.keys.index_with { [] }
      CardSeason.where(season_id: season.id).order(:id).pluck(:rarity, :id).each do |rarity, id|
        tiers.fetch(CardSeason.rarities.fetch(rarity)) << id
      end
      { season_id: season.id, tiers: }
    end
  end
end
