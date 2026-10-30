module Game
  class CollectAchievement < Operation
    def call(player:, achievement:)
      player = step require_player(player)
      achievement = step known(achievement)

      transaction do
        step lock_bank(player)
        step collect(player, achievement)
        step publish(AchievementCollected.new(data: { player_id: player.id, achievement: achievement.key.to_s }), stream_name: stream_name(player.id))
        achievement
      end
    end

    private

    def known(key)
      achievement = Achievements.find(key.to_s)
      achievement ? Success(achievement) : Failure(:unknown_achievement)
    end

    def collect(player, achievement)
      AchievementUnlock.collect(player.id, achievement.key, Time.current) ? Success() : Failure(:not_ready)
    end
  end
end
