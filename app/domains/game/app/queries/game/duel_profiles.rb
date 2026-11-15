module Game
  module DuelProfiles
    Stat = Data.define(:name, :value, :percentile, :median_distance, :weekly_percentile) do
      def value? = !value.nil?
    end

    Profile = Data.define(:card_season_id, :stats, :trump_stat, :trump_direction, :computed_at) do
      def trump = stats.find { it.name == trump_stat }

      def ranked? = stats.find { it.name == :discovery }.value?
    end

    Change = Data.define(:card_season_id, :card_id, :stat, :from, :to) do
      def amount = to - from
    end

    def self.call(card_season_ids)
      DuelStat.where(card_season_id: card_season_ids).to_h { [ it.card_season_id, profile(it) ] }
    end

    def self.weekly_changes
      columns = DuelStat::STATS.flat_map { [ "game_duel_stats.#{it}_weekly_percentile", "game_duel_stats.#{it}_percentile" ] }
      DuelStat.joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_duel_stats.card_season_id")
        .pluck(Arel.sql("game_duel_stats.card_season_id"), Arel.sql("catalog_card_seasons.card_id"), *columns.map { Arel.sql(it) })
        .flat_map do |card_season_id, card_id, *percentiles|
          DuelStat::STATS.zip(percentiles.each_slice(2).to_a).filter_map do |stat, (from, to)|
            Change.new(card_season_id:, card_id:, stat:, from:, to:) unless from.nil? || to.nil?
          end
        end
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
