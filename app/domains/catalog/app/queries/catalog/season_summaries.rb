module Catalog
  module SeasonSummaries
    Summary = Data.define(:number, :status, :published_at, :card_count, :tier_counts, :set_counts) do
      def draft? = status == "draft"
      def published? = status == "published"
    end

    def self.call
      counts = CardSeason.group(:season_id, :rarity).count
      set_counts = Set.group(:season_id, :kind).count
      Season.order(:number).map do |season|
        by_rarity = counts.select { |(season_id, _), _| season_id == season.id }
          .transform_keys { |(_, rarity)| rarity && CardSeason.rarities.fetch(rarity) }
        Summary.new(
          number: season.number,
          status: season.status,
          published_at: season.published_at,
          card_count: by_rarity.values.sum,
          tier_counts: season.published? ? Rarity::TIERS.keys.index_with { |tier| by_rarity.fetch(tier, 0) } : nil,
          set_counts: season.published? ? Set.kinds.keys.index_with { |kind| set_counts.fetch([ season.id, kind ], 0) } : nil
        )
      end
    end
  end
end
