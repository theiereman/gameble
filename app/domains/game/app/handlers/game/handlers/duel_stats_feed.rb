module Game
  module Handlers
    module DuelStatsFeed
      def self.call(event)
        return unless event.data.fetch(:reason) == "weekly"

        moves = DuelStatMoves.new(DuelProfiles.weekly_changes).rows
        return if moves.empty?

        now = event.metadata[:timestamp] || Time.current
        FeedEntry.record_duel_stats(moves:, week_start: WeeklyGoal.week_start(now), now:)
      end
    end
  end
end
