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

        position = step free_position(player)
        step incomplete(aim)
        goal = Goal.create!(player_id: player.id, position:, **aim.columns)
        step goal_published(GoalAdded, player, goal)
        goal
      end
    end

    private

    def free_position(player)
      position = (Goal::POSITIONS.to_a - Goal.where(player_id: player.id).pluck(:position)).first
      position ? Success(position) : Failure(:too_many_goals)
    end

    def incomplete(aim)
      aim.complete ? Failure(:goal_set_complete) : Success()
    end
  end
end
