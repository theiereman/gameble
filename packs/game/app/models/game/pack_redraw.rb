module Game
  # Packs drawn in an earlier season, drawn again in the published one: each
  # card within its old card's tier, so a pack keeps its kind's odds, its
  # size and any card it was guaranteed (the first session's rare, a reward
  # pack's Épique or better), which nothing on the pack records. A pack
  # already of the pool's season is left out. Game::HealBank redraws a bank
  # when a season is published; Game::OpenPack redraws a pack that opens
  # before that.
  #
  #   Game::PackRedraw.call(packs, pool:) # => { pack => { season_id:, card_season_ids: }, … }
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
