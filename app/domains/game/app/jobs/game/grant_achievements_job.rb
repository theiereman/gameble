module Game
  class GrantAchievementsJob < ActiveJob::Base
    queue_as :default

    def self.grant(player, retroactive: false)
      unlocked = UnlockedAchievements.call(player)
      Achievements.met(AchievementProgress.call(player)).reject { unlocked.include?(it.key) }.map do |achievement|
        GrantAchievement.new.call(player:, achievement: achievement.key, retroactive:)
      end
    end

    def perform(player_id, retroactive: false)
      player = Accounts::PlayerById.call(player_id)
      return if player.nil? || player.banned? || player.deleted?

      self.class.grant(player, retroactive:)
    end
  end
end
