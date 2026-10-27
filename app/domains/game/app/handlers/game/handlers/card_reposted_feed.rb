module Game
  module Handlers
    module CardRepostedFeed
      def self.call(event)
        FeedEntry.record_repost(player_id: event.data.fetch(:player_id), card_season_id: event.data.fetch(:card_season_id),
          at: event.metadata[:timestamp] || Time.current)
      end
    end
  end
end
