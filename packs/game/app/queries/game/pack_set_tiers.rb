module Game
  # The set tiers an opening reached, read back by its pack, so a replay
  # answers them as the first answer did: each with its set's kind, key and
  # params, the cards the tier asks for and the set's card count (its
  # complete tier), by set then tier.
  #
  #   Game::PackSetTiers.call(pack) # => [ Row(kind: "theme", key: "roguelike", params: {…}, tier: "silver", required: 16, total: 62), … ]
  module PackSetTiers
    Row = Data.define(:kind, :key, :params, :tier, :required, :total)

    def self.call(pack)
      SetTier.where(pack_id: pack.id)
        .joins("JOIN catalog_sets ON catalog_sets.id = game_set_tiers.set_id")
        .joins("JOIN catalog_set_tiers AS reached ON reached.set_id = game_set_tiers.set_id AND reached.tier = game_set_tiers.tier")
        .joins("JOIN catalog_set_tiers AS complete ON complete.set_id = game_set_tiers.set_id AND complete.tier = 'complete'")
        .order(:set_id, Arel.sql(SetTier.sanitize_sql_array([ "array_position(ARRAY[?]::varchar[], game_set_tiers.tier)", SetTier::TIERS ])))
        .pluck("catalog_sets.kind", "catalog_sets.key", "catalog_sets.params", "game_set_tiers.tier", "reached.required", "complete.required")
        .map { |kind, key, params, tier, required, total| Row.new(kind:, key:, params:, tier:, required:, total:) }
    end
  end
end
