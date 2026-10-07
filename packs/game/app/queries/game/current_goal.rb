module Game
  # The weekly goal the hub shows (CAP-12): the total summed so far and the
  # target of the current UTC week, whether it is reached, and how the
  # previous week ended (its final count, reached or missed; nil without a
  # goal that week), one indexed read. Before the periodic job has created
  # the week's goal, the total is 0 and the target is computed from last
  # week's contributions.
  #
  #   Game::CurrentGoal.call
  #   # => { total: n, target: n, reached: bool, previous: { total: n, target: n, reached: bool } | nil }
  module CurrentGoal
    def self.call(now: Time.current)
      week = WeeklyGoal.week_start(now)
      goals = WeeklyGoal.where(week_start: [ week - 7, week ]).pluck(:week_start, :total, :target)
                        .to_h { |start, total, target| [ start, figures(total, target) ] }
      { **goals.fetch(week) { figures(0, WeeklyGoal.target_for(week)) }, previous: goals[week - 7] }
    end

    def self.figures(total, target) = { total:, target:, reached: total >= target }

    private_class_method :figures
  end
end
