module GoalHelper
  SEGMENTS = 24

  def goal_lit_segments(goal)
    return 0 unless goal[:target].positive?

    (goal[:total].clamp(0, goal[:target]) * SEGMENTS) / goal[:target]
  end
end
