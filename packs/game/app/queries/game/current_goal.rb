module Game
  # The weekly goal the hub shows (CAP-12): the total summed so far and the
  # target of the current UTC week, one indexed read. Before the periodic job
  # has created the week's goal, the total is 0 and the target is computed
  # from last week's contributions.
  #
  #   Game::CurrentGoal.call # => { total: n, target: n }
  module CurrentGoal
    def self.call(now: Time.current)
      week = WeeklyGoal.week_start(now)
      goal = WeeklyGoal.where(week_start: week).pick(:total, :target)
      goal ? { total: goal[0], target: goal[1] } : { total: 0, target: WeeklyGoal.target_for(week) }
    end
  end
end
