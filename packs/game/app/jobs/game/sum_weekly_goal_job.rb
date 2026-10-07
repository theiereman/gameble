module Game
  # Sums the weekly contributions into the goal's total (CAP-12, AD-10,
  # AD-12), on a schedule (config/recurring.yml): the current week's goal is
  # created on first run, its target fixed from the previous week's active
  # players; the current and the previous week are summed, so the last
  # openings of a week that just ended are counted. One aggregate and one
  # update per week; a rerun changes nothing but the sum.
  class SumWeeklyGoalJob < ActiveJob::Base
    queue_as :default

    def perform(now: Time.current)
      current = WeeklyGoal.week_start(now)
      ensure_goal(current)
      [ current - 7, current ].each { |week| sum(week, now) }
    end

    private

    def ensure_goal(week)
      return if WeeklyGoal.exists?(week_start: week)

      WeeklyGoal.insert({ week_start: week, target: WeeklyGoal.target_for(week), total: 0 }, unique_by: :week_start)
    end

    def sum(week, now)
      total = WeeklyContribution.where(week_start: week).sum(:openings)
      WeeklyGoal.where(week_start: week).where.not(total:).update_all([ "total = ?, summed_at = ?, updated_at = ?", total, now, now ])
    end
  end
end
