module Game
  module Handlers
    module SetTierFeed
      EVENTS = [ Game::SetTierReached, Game::SetCompleted ].freeze

      def self.call(event)
        FeedEntry.record_sets(player_id: event.data.fetch(:player_id), set_id: event.data.fetch(:set_id), tier: tier(event),
          now: event.metadata[:timestamp] || Time.current)
      end

      def self.tier(event) = event.is_a?(Game::SetCompleted) ? "complete" : event.data.fetch(:tier)
      private_class_method :tier
    end
  end
end
