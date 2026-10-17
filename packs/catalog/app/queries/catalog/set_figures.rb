module Catalog
  module SetFigures
    Figures = Data.define(:total, :tiers)

    TOTAL = Arel.sql("(SELECT COUNT(*) FROM catalog_set_memberships AS members WHERE members.set_id = catalog_sets.id)").freeze
    TIERS = Arel.sql(<<~SQL.squish).freeze
      (SELECT json_object_agg(tiers.tier, tiers.required) FROM catalog_set_tiers AS tiers WHERE tiers.set_id = catalog_sets.id)
    SQL

    def self.call(set_ids)
      return {} if set_ids.empty?

      Set.where(id: set_ids.uniq).pluck(:id, TOTAL, TIERS).to_h do |id, total, tiers|
        [ id, Figures.new(total: total.to_i, tiers: tier_hash(tiers)) ]
      end
    end

    def self.tier_hash(value)
      (value.is_a?(String) ? JSON.parse(value) : value || {}).transform_values(&:to_i)
    end
    private_class_method :tier_hash
  end
end
