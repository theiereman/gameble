module Game
  class GrantAchievement < Operation
    def call(player:, achievement:, retroactive: false)
      player = step require_player(player)
      achievement = step known(achievement)

      transaction do
        step lock_bank(player)
        step reached(player, achievement)
        step unlock(player, achievement, retroactive)
        step publish(AchievementUnlocked.new(data: event_data(player, achievement, retroactive)), stream_name: stream_name(player.id))
        achievement
      end
    end

    private

    def known(key)
      achievement = Achievements.find(key)
      achievement ? Success(achievement) : Failure(:unknown_achievement)
    end

    def reached(player, achievement)
      achievement.met?(AchievementProgress.call(player, [ achievement.metric ])) ? Success() : Failure(:not_reached)
    end

    def unlock(player, achievement, retroactive)
      AchievementUnlock.record(player.id, achievement.key, Time.current, claimed: nothing_to_claim?(achievement, retroactive)) ? Success() : Failure(:already_unlocked)
    end

    def nothing_to_claim?(achievement, retroactive)
      retroactive || CardBacks.for_achievement(achievement.key).nil?
    end

    def event_data(player, achievement, retroactive)
      data = { player_id: player.id, achievement: achievement.key.to_s }
      retroactive ? data.merge(retroactive: true) : data
    end
  end
end
