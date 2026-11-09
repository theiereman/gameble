module Game
  module Handlers
    module WeeklyVerdictFeed
      def self.call(event)
        FeedEntry.record_verdict(player_id: event.data.fetch(:player_id), week_start: Date.iso8601(event.data.fetch(:week_start)),
          now: event.metadata[:timestamp] || Time.current)
      end
    end
  end
end
