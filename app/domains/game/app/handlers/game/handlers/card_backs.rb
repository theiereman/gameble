module Game
  module Handlers
    module CardBacks
      EVENTS = {
        Game::SetTierReached => false,
        Game::SetCompleted => false,
        Game::SeasonAllocationReceived => true
      }.freeze

      def self.call(event)
        GrantCardBacksJob.perform_later(event.data.fetch(:player_id), retroactive: EVENTS.fetch(event.class))
      end
    end
  end
end
