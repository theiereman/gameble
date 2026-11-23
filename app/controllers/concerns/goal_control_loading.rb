module GoalControlLoading
  extend ActiveSupport::Concern

  private
    def load_goal_control(aim, targets: Game::GoalNeeds.targets(current_player))
      @goal_aim = aim
      @goal = targets.find { it.aims_at?(**aim) }
      @goal_slot = Game::SlotOffer.call(:goal, limit: Game::Capacity.limit(current_player, :goal), used: targets.size) unless @goal
    end
end
