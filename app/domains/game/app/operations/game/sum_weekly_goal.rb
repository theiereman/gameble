module Game
  class SumWeeklyGoal < ApplicationOperation
    def call(week_start:, now:)
      total = WeeklyContribution.where(week_start:).sum(Arel.sql("openings + trades"))
      moved = WeeklyGoal.where(week_start:).where.not(total:)
        .update_all([ "total = ?, summed_at = ?, updated_at = ?", total, now, now ])
      moved.positive?
    end
  end
end
