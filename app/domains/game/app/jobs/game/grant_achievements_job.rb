module Game
  class GrantAchievementsJob < ActiveJob::Base
    queue_as :default

    def self.grant(player, retroactive: false)
      unearned = Achievements.unearned(UnlockedAchievements.call(player))
      progress = AchievementProgress.call(player, Achievements.metrics(unearned))
      unearned.select { it.met?(progress) }.map do |achievement|
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
