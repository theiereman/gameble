module Game
  # The set tiers an opening reached, read back by its pack, so a replay
  # answers them as the first answer did: each with its set's kind, key and
  # params, the cards the tier asks for, the set's card count (its complete
  # tier) and every tier of the set before completion as [tier, required]
  # pairs, the fewest cards first (none for a set too small for tiers); by
  # set, then by the count the tier asks.
  #
  #   Game::PackSetTiers.call(pack)
  #   # => [ Row(kind: "theme", key: "roguelike", params: {…}, tier: "silver", required: 16, total: 62,
  #   #          thresholds: [ [ "bronze", 7 ], [ "silver", 16 ], [ "gold", 31 ] ]), … ]
  module PackSetTiers
    Row = Data.define(:kind, :key, :params, :tier, :required, :total, :thresholds)

    def self.call(pack)
      reached = SetTier.where(pack_id: pack.id)
        .joins("JOIN catalog_sets ON catalog_sets.id = game_set_tiers.set_id")
        .joins("JOIN catalog_set_tiers AS reached ON reached.set_id = game_set_tiers.set_id AND reached.tier = game_set_tiers.tier")
        .joins("JOIN catalog_set_tiers AS complete ON complete.set_id = game_set_tiers.set_id AND complete.tier = 'complete'")
        .joins(tier_order_join("game_set_tiers.tier"))
        .order(:set_id, "reached.required", "tier_order.position")
        .pluck("game_set_tiers.set_id", "catalog_sets.kind", "catalog_sets.key", "catalog_sets.params", "game_set_tiers.tier", "reached.required", "complete.required")
      thresholds = thresholds_by_set(reached.map(&:first).uniq)
      reached.map do |set_id, kind, key, params, tier, required, total|
        set_thresholds = total >= Catalog::TierTable::SMALLEST_TIERED ? thresholds.fetch(set_id, []) : []
        Row.new(kind:, key:, params:, tier:, required:, total:, thresholds: set_thresholds)
      end
    end

    def self.thresholds_by_set(set_ids)
      return {} if set_ids.empty?

      Catalog::SetTier.where(set_id: set_ids).where.not(tier: Catalog::SetTier::COMPLETE)
        .joins(tier_order_join("catalog_set_tiers.tier"))
        .order(:set_id, :required, "tier_order.position")
        .pluck(:set_id, :tier, :required)
        .group_by(&:first)
        .transform_values { |rows| rows.map { |_set_id, tier, required| [ tier, required ] } }
    end

    def self.tier_order_join(column)
      SetTier.sanitize_sql_array([ "JOIN #{SetTier::TIER_ORDER_SQL} ON tier_order.tier = #{column}", { tiers: SetTier::TIERS } ])
    end
    private_class_method :thresholds_by_set, :tier_order_join
  end
end
