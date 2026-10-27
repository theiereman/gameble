module Game
  module CurrentGoal
    def self.call(now: Time.current)
      week = WeeklyGoal.week_start(now)
      goals = WeeklyGoal.where(week_start: [ week - 7, week ]).pluck(:week_start, :total, :target)
                        .to_h { |start, total, target| [ start, figures(total, target) ] }
      { **goals.fetch(week) { figures(0, WeeklyGoal.target_for(week)) }, previous: goals[week - 7] }
    end

    def self.next_week_start(now = Time.current)
      (WeeklyGoal.week_start(now) + 7).in_time_zone("UTC")
    end

    def self.figures(total, target) = { total:, target:, reached: total >= target }

    private_class_method :figures
  end
end
