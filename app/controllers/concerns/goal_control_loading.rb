module GoalControlLoading
  extend ActiveSupport::Concern
  include GoalMarksLoading

  private
    def load_goal_control(aim, targets: Game::GoalNeeds.targets(current_player))
      @goal_aim = aim
      @goal = targets.find { it.aims_at?(**aim) }
      @goal_slot = Game::SlotOffer.call(:goal, limit: Game::Capacity.limit(current_player, :goal), used: targets.size) unless @goal
      @goal_orders = @goal ? cards_to_order(@goal) : []
    end

    def cards_to_order(goal)
      needs = goal_marks.needs.select { it.goal_id == goal.goal_id }
      Game::Market::CardsToOrder.call(current_player, needs, locale: I18n.locale).fetch(goal.goal_id, [])
    end
end
