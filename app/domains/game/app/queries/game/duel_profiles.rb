module Game
  module DuelProfiles
    Stat = Data.define(:name, :value, :percentile, :median_distance, :weekly_percentile) do
      def value? = !value.nil?
    end

    Profile = Data.define(:card_season_id, :stats, :trump_stat, :trump_direction, :computed_at) do
      def trump = stats.find { it.name == trump_stat }

      def ranked? = stats.find { it.name == :discovery }.value?
    end

    def self.call(card_season_ids)
      DuelStat.where(card_season_id: card_season_ids).to_h { [ it.card_season_id, profile(it) ] }
    end

    def self.profile(row)
      stats = DuelStat::STATS.map do |name|
        Stat.new(name:, value: row[:"#{name}_value"], percentile: row[:"#{name}_percentile"],
          median_distance: row[:"#{name}_median_distance"], weekly_percentile: row[:"#{name}_weekly_percentile"])
      end
      Profile.new(card_season_id: row.card_season_id, stats:, trump_stat: row.trump_stat.to_sym,
        trump_direction: row.trump_direction, computed_at: row.computed_at)
    end
    private_class_method :profile
  end
end
