# The community goal panel's gauge (DESIGN.md, Community goal panel).
module GoalHelper
  SEGMENTS = 24

  # How many of the gauge's segments are lit for `goal` ({ total:, target: }):
  # the share reached, rounded down, so a full gauge means a reached goal.
  def goal_lit_segments(goal)
    return 0 unless goal[:target].positive?

    (goal[:total].clamp(0, goal[:target]) * SEGMENTS) / goal[:target]
  end
end
