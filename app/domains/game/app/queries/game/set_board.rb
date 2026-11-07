module Game
  module SetBoard
    Board = Data.define(:in_progress, :complete)
    EMPTY = Board.new(in_progress: [], complete: [])

    def self.call(player, season:)
      return EMPTY if season.nil?

      standings = SetsInProgress.call(player, season:).values
      in_progress = ranked_in_progress(standings)
      Board.new(in_progress:, complete: latest_complete(standings - in_progress))
    end

    def self.ranked_in_progress(standings)
      standings.select(&:in_progress?).sort_by do |standing|
        lead = if standing.just && standing.reached_now then 0 elsif standing.just then 1 else 2 end
        [ lead, standing.missing || 0, -standing.share, standing.set_id ]
      end
    end

    def self.latest_complete(standings)
      standings.select(&:complete?).sort_by do |standing|
        completed_at = standing.completed_at || standing.gained_at
        [ completed_at ? 0 : 1, -completed_at.to_r, standing.set_id ]
      end
    end

    private_class_method :ranked_in_progress, :latest_complete
  end
end
