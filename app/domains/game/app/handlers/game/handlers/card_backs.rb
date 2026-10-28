module Game
  module Handlers
    module CardBacks
      EVENTS = {
        Game::SetTierReached => false,
        Game::SetCompleted => false,
        Game::SeasonAllocationReceived => true,
        Game::GoalRewardGranted => false,
        Game::AchievementUnlocked => false
      }.freeze

      def self.call(event)
        GrantCardBacksJob.perform_later(event.data.fetch(:player_id), retroactive: EVENTS.fetch(event.class) || event.data.fetch(:retroactive, false))
      end
    end
  end
end
