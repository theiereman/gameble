module Game
  module Handlers
    module CardBacks
      EVENTS = {
        Game::SetTierReached => false,
        Game::SetCompleted => false,
        Game::SeasonAllocationReceived => true,
        Game::GoalRewardGranted => false,
        Game::AchievementCollected => false
      }.freeze

      def self.call(event)
        retroactive = EVENTS.fetch(event.class) || event.data.fetch(:retroactive, false)
        GrantCardBacksJob.perform_later(event.data.fetch(:player_id), retroactive:)
      end
    end
  end
end
