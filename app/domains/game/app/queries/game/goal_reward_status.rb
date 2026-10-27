module Game
  module GoalRewardStatus
    WAITING_FIRST = Arel.sql("pack_id IS NULL DESC, CASE WHEN pack_id IS NULL THEN week_start END ASC, updated_at DESC")

    def self.call(player, now: Time.current)
      rewards = GoalReward.where(player_id: player.id)
      claimed_since = (WeeklyGoal.week_start(now) - 7).in_time_zone("UTC")
      week_start, pack_id = rewards.unclaimed.or(rewards.where(updated_at: claimed_since..))
                                   .order(WAITING_FIRST).pick(:week_start, :pack_id)
      { week_start:, claimed: pack_id.present? } if week_start
    end
  end
end
