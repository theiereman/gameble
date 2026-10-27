module Game
  module PackSetTiers
    Row = Data.define(:kind, :key, :params, :tier, :required, :held, :total, :thresholds)

    def self.call(pack)
      reached = SetTier.where(pack_id: pack.id)
        .joins("JOIN catalog_sets ON catalog_sets.id = game_set_tiers.set_id")
        .joins("JOIN catalog_set_tiers AS reached ON reached.set_id = game_set_tiers.set_id AND reached.tier = game_set_tiers.tier")
        .joins("JOIN catalog_set_tiers AS complete ON complete.set_id = game_set_tiers.set_id AND complete.tier = 'complete'")
        .joins(tier_order_join("game_set_tiers.tier"))
        .order(:set_id, "reached.required", "tier_order.position")
        .pluck("game_set_tiers.set_id", "catalog_sets.kind", "catalog_sets.key", "catalog_sets.params", "game_set_tiers.tier", "reached.required",
          Arel.sql("COALESCE(game_set_tiers.held, reached.required)"), "complete.required")
      thresholds = thresholds_by_set(reached.map(&:first).uniq)
      reached.map do |set_id, kind, key, params, tier, required, held, total|
        set_thresholds = Catalog::TierTable.tiered?(total) ? thresholds.fetch(set_id, []) : []
        Row.new(kind:, key:, params:, tier:, required:, held:, total:, thresholds: set_thresholds)
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
