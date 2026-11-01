module GoalControlLoading
  extend ActiveSupport::Concern

  private
    def load_goal_control(aim, targets: Game::GoalNeeds.targets(current_player))
      @goal_aim = aim
      @goal = targets.find { it.aims_at?(**aim) }
    end
end
