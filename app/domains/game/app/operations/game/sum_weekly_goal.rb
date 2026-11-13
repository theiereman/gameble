module Game
  class SumWeeklyGoal < ApplicationOperation
    def call(week_start:, now:)
      total = WeeklyContribution.total_for(week_start)
      moved = WeeklyGoal.where(week_start:).where.not(total:)
        .update_all([ "total = ?, summed_at = ?, updated_at = ?", total, now, now ])
      moved.positive?
    end
  end
end
