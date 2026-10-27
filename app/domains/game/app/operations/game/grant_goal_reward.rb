module Game
  # Records that a contributor earned the reward of a reached weekly goal. The
  # reward waits without a pack until the player claims it
  # (Game::ClaimGoalReward), whatever their reserve holds, so it is never
  # lost. Under the bank lock:
  #
  # 1. the week's goal is not reached: Failure(:goal_not_reached);
  # 2. the player has no contribution that week: Failure(:not_contributor);
  # 3. a reward for that week exists: Failure(:already_granted);
  # 4. the reward row (Game::GoalReward) is inserted with no pack, and
  #    Game::GoalRewardGranted is published.
  #
  # The lock serialises a player's grants; the unique index on (player_id,
  # week_start) is the database's guarantee behind it. Run by
  # Game::GrantGoalRewardsJob, one player per transaction. A player whose
  # account was deleted while it waited on the lock gets nothing
  # (Game::Operation#lock_bank).
  #
  #   Game::GrantGoalReward.new.call(player:, week_start: Date)
  #   # => Success(goal_reward) | Failure(:player_required) | Failure(:goal_not_reached) | Failure(:not_contributor)
  #   #    | Failure(:already_granted)
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
