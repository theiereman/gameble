module Game
  module Handlers
    module SetTierFeed
      EVENTS = [ Game::SetCompleted ].freeze

      def self.call(event)
        FeedEntry.record_completion(player_id: event.data.fetch(:player_id), set_id: event.data.fetch(:set_id),
          now: event.metadata[:timestamp] || Time.current)
      end
    end
  end
end
