module GoalHelper
  def goal_lit_segments(goal)
    GaugeComponent.lit(goal[:total], goal[:target])
  end
end
