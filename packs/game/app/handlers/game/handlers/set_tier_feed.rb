module Game
  module Handlers
    # Puts in the activity feed the tiers an operation reached for a player:
    # one entry per player and operation (Game::FeedEntry.record_sets). It
    # runs in the operation's transaction, writes one upsert and publishes
    # nothing.
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
