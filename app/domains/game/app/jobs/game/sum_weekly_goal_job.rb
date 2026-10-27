module Game
  class SumWeeklyGoalJob < ActiveJob::Base
    queue_as :default

    def perform(now: Time.current)
      current = WeeklyGoal.week_start(now)
      CreateWeeklyGoal.new.call(week_start: current).value!
      [ current - 7, current ].each { |week| sum(week, now) }
    end

    private

    def sum(week, now)
      moved = SumWeeklyGoal.new.call(week_start: week, now:).value!
      GrantGoalRewardsJob.perform_later(week_start: week) if moved && WeeklyGoal.reached.exists?(week_start: week)
    end
  end
end
