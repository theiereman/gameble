module Game
  class WeeklyGoal < ApplicationRecord
    self.table_name = "game_weekly_goals"

    PER_PLAYER = 50
    FLOOR = 200

    scope :reached, -> { where("total >= target") }

    def self.week_start(time) = time.utc.to_date.beginning_of_week(:monday)

    def self.target_for(week_start)
      active = WeeklyContribution.where(week_start: week_start - 7, openings: 1..).count
      [ active * PER_PLAYER, FLOOR ].max
    end
  end
end
