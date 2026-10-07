module Game
  module Handlers
    # Counts an opening toward the weekly goal (CAP-12, AD-9, AD-10): one
    # upsert on the opener's own contribution row for the UTC week, inside
    # the opening's transaction. It writes no row shared between players;
    # the goal's total is summed by a periodic job (Game::SumWeeklyGoalJob).
    module PackOpened
      def self.call(event)
        WeeklyContribution.record_opening(event.data.fetch(:player_id), event.metadata[:timestamp] || Time.current)
      end
    end
  end
end
