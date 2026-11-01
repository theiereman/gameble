module GoalControlLoading
  extend ActiveSupport::Concern

  private
    def load_goal_control(aim)
      @goal_aim = aim
      @goal = Game::GoalNeeds.targets(current_player).find { it.aims_at?(**aim) }
    end
end
