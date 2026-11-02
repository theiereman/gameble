module Game
  class ClaimAchievement < Operation
    def call(player:, achievement:)
      player = step require_player(player)
      achievement = step known(achievement)

      transaction do
        step lock_bank(player)
        step claim(player, achievement)
        step publish(AchievementClaimed.new(data: { player_id: player.id, achievement: achievement.key.to_s }), stream_name: stream_name(player.id))
        achievement
      end
    end

    private

    def known(key)
      achievement = Achievements.find(key)
      achievement ? Success(achievement) : Failure(:unknown_achievement)
    end

    def claim(player, achievement)
      unlock = AchievementUnlock.find_by(player_id: player.id, achievement: achievement.key.to_s)
      return Failure(:achievement_not_earned) unless unlock
      return Failure(:achievement_already_claimed) if unlock.claimed_at

      unlock.update!(claimed_at: Time.current)
      Success()
    end
  end
end
