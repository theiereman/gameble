module Game
  class RemoveGoal < Operation
    include GoalSteps

    def call(player:, kind: nil, key: nil, custom_set: nil)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        columns = goal_columns(player, kind:, key:, custom_set:)
        goal = Goal.find_by(player_id: player.id, **columns) if columns
        next if goal.nil?

        goal.delete
        step goal_published(GoalRemoved, player, goal)
        goal
      end
    end
  end
end
