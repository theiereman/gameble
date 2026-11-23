module Game
  class AddGoal < Operation
    include GoalSteps

    def call(player:, kind: nil, key: nil, custom_set: nil)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        aim = step goal_aim(player, kind:, key:, custom_set:)
        existing = Goal.find_by(player_id: player.id, **aim.columns)
        next existing if existing

        goal = step goal_inserted(player, aim)
        step goal_published(GoalAdded, player, goal)
        goal
      end
    end
  end
end
