module Game
  module SetBackProgress
    Progress = Data.define(:held, :total, :required) do
      def missing = required - held
    end

    def self.call(player, keys)
      season = Catalog::PublishedSeason.call
      sets = set_ids(season, keys.to_set)
      return {} if sets.empty?

      standings = SetsInProgress.call(player, season:)
      figures = Catalog::SetFigures.call(sets.values)
      sets.filter_map do |key, id|
        figure = figures[id] or next
        [ key, Progress.new(held: standings[id]&.held || 0, total: figure.total, required: back_tier_required(figure)) ]
      end.to_h
    end

    def self.set_ids(season, keys)
      return {} if season.nil? || keys.empty?

      Catalog::SeasonSets.every_kind(season:).where(kind: EarnedSetBacks::KINDS).pluck(:kind, :key, :id)
        .to_h { |kind, key, id| [ CardBacks.set_key(kind, key), id ] }
        .slice(*keys)
    end

    def self.back_tier_required(figure)
      complete = figure.tiers.fetch(Catalog::SetTier::COMPLETE, figure.total)
      figure.tiers.values.select { it * 2 >= complete }.min || complete
    end

    private_class_method :set_ids, :back_tier_required
  end
end
