module GoalsReachedTracking
  extend ActiveSupport::Concern

  private
    def tracking_goals_reached(player)
      before = Game::GoalNeeds.targets(player)
      result = yield
      return [ result, [] ] if before.empty? || result.failure?

      kept = Game::GoalNeeds.targets(player).map(&:goal_id)
      [ result, before.reject { kept.include?(it.goal_id) }.map { helpers.goal_set_name(it) } ]
    end

    def toast_goals_reached(names)
      flash[:goals_reached] = names if names.any?
    end
end
