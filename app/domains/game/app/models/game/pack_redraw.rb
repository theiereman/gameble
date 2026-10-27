module Game
  module PackRedraw
    def self.call(packs, pool:, random: SecureRandom)
      stale = packs.reject { |pack| pack.season_id == pool.season_id }
      tiers = Catalog::CardSeasonTiers.call(stale.flat_map(&:card_season_ids))
      stale.index_with do |pack|
        { season_id: pool.season_id, card_season_ids: Draw.in_tiers(pack.card_season_ids.map { tiers.fetch(it) }, random:, pool:) }
      end
    end
  end
end
