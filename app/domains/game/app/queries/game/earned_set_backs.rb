module Game
  module EarnedSetBacks
    KINDS = CardBacks::SET_KEYS.keys.freeze

    SQL = <<~SQL.squish.freeze
      SELECT DISTINCT sets.kind, sets.key
        FROM game_set_tiers AS earned
        JOIN catalog_sets AS sets ON sets.id = earned.set_id
        JOIN catalog_set_tiers AS complete ON complete.set_id = sets.id AND complete.tier = 'complete'
        JOIN catalog_set_tiers AS back_tier ON back_tier.set_id = sets.id AND back_tier.tier = earned.tier
       WHERE earned.player_id = :player_id
         AND sets.kind IN (:kinds)
         AND back_tier.required * 2 >= complete.required
         AND NOT EXISTS (
           SELECT 1 FROM catalog_set_tiers AS lower
            WHERE lower.set_id = sets.id AND lower.required < back_tier.required AND lower.required * 2 >= complete.required
         )
    SQL

    def self.call(player)
      sql = Catalog::Set.sanitize_sql_array([ SQL, { player_id: player.id, kinds: KINDS } ])
      Catalog::Set.connection.select_rows(sql, "Game::EarnedSetBacks").map { |kind, key| CardBacks.set_key(kind, key) }.select { CardBacks.find(it) }
    end
  end
end
