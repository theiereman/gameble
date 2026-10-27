module Game
  module SetBoard
    Board = Data.define(:in_progress, :complete)
    EMPTY = Board.new(in_progress: [], complete: [])
    HUB_ROWS = 4

    def self.call(player, season:)
      return EMPTY if season.nil?

      standings = SetsInProgress.call(player, season:).values
      in_progress = ranked_in_progress(standings)
      Board.new(in_progress:, complete: latest_complete(standings - in_progress))
    end

    def self.hub(player, season:)
      return [] if season.nil?

      standings = SetsInProgress.call(player, season:)
      rows = ranked_in_progress(standings.values).first(HUB_ROWS)
      rows += ranked_touched(standings.values).first(HUB_ROWS - rows.size)
      rows + popular(season, HUB_ROWS - rows.size, exclude: standings.keys)
    end

    def self.ranked_in_progress(standings)
      standings.select(&:in_progress?).sort_by do |standing|
        lead = if standing.just && standing.reached_now then 0 elsif standing.just then 1 else 2 end
        [ lead, standing.missing || 0, -standing.share, standing.set_id ]
      end
    end

    def self.ranked_touched(standings)
      standings.select { |standing| standing.started? && !standing.in_progress? && !standing.complete? }
        .sort_by { |standing| [ standing.gained_at ? 0 : 1, -standing.gained_at.to_r, standing.set_id ] }
    end

    def self.latest_complete(standings)
      standings.select(&:complete?).sort_by do |standing|
        completed_at = standing.completed_at || standing.gained_at
        [ completed_at ? 0 : 1, -completed_at.to_r, standing.set_id ]
      end
    end

    def self.popular(season, count, exclude:)
      ids = Catalog::PopularSets.call(season:, limit: count, exclude:)
      figures = Catalog::SetFigures.call(ids)
      ids.filter_map do |set_id|
        figure = figures[set_id]
        SetStanding.unstarted(set_id:, total: figure.total, tiers: figure.tiers) if figure
      end
    end

    private_class_method :ranked_in_progress, :ranked_touched, :latest_complete, :popular
  end
end
