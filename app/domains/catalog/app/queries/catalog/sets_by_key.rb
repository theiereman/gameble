module Catalog
  module SetsByKey
    Entry = Data.define(:set, :card_ids, :tiers)

    def self.sets(season:, keys:)
      keys = keys.map { |kind, key| [ kind.to_s, key.to_s ] }.uniq
      return {} if season.nil? || keys.empty?

      Set.where(season_id: season.id).where([ :kind, :key ] => keys).index_by { [ it.kind, it.key ] }
    end

    def self.call(season:, keys:)
      sets = sets(season:, keys:)
      return {} if sets.empty?

      ids = sets.values.map(&:id)
      members = SetMembership.where(set_id: ids).joins(:card_season).order(:set_id, :position, :id)
        .pluck(:set_id, Arel.sql("catalog_card_seasons.card_id")).group_by(&:first)
      tiers = SetTier.where(set_id: ids).pluck(:set_id, :tier, :required).group_by(&:first)
      sets.transform_values do |set|
        Entry.new(set:, card_ids: members.fetch(set.id, []).map(&:last), tiers: tiers.fetch(set.id, []).to_h { |_id, tier, required| [ tier, required ] })
      end
    end
  end
end
