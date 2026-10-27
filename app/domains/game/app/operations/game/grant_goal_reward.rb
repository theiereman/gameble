module Game
  class GrantGoalReward < Operation
    def call(player:, week_start:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        step reached(week_start)
        step contributed(player, week_start)
        step ungranted(player, week_start)
        reward = GoalReward.create!(player_id: player.id, week_start:)
        step publish(GoalRewardGranted.new(data: { player_id: player.id, week_start: week_start.iso8601 }),
          stream_name: stream_name(player.id))
        reward
      end
    end

    private

    def reached(week_start)
      WeeklyGoal.reached.exists?(week_start:) ? Success() : Failure(:goal_not_reached)
    end

    def contributed(player, week_start)
      WeeklyContribution.exists?(player_id: player.id, week_start:) ? Success() : Failure(:not_contributor)
    end

    def ungranted(player, week_start)
      GoalReward.exists?(player_id: player.id, week_start:) ? Failure(:already_granted) : Success()
    end
  end
end
