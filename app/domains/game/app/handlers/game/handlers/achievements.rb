module Game
  module Handlers
    module Achievements
      EVENTS = {
        Game::PackOpened => [ :player_id ],
        Game::SetCompleted => [ :player_id ],
        Game::CardReposted => [ :player_id ],
        Game::TradeAccepted => [ :proposer_id, :recipient_id ]
      }.freeze

      def self.call(event)
        EVENTS.fetch(event.class).each { GrantAchievementsJob.perform_later(event.data.fetch(it)) }
      end
    end
  end
end
