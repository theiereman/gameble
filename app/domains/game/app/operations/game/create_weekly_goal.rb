module Game
  class CreateWeeklyGoal < ApplicationOperation
    def call(week_start:)
      return if WeeklyGoal.exists?(week_start:)

      WeeklyGoal.insert({ week_start:, target: WeeklyGoal.target_for(week_start), total: 0 }, unique_by: :week_start)
    end
  end
end
