module Game
  class WeeklyGoal < ApplicationRecord
    self.table_name = "game_weekly_goals"

    FLOOR = 500
    GROWTH_FACTOR = 1.05r
    STEP = 10

    scope :reached, -> { where("total >= target") }

    def self.week_start(time) = time.utc.to_date.beginning_of_week(:monday)

    def self.target_for(week_start)
      previous_target = where(week_start: week_start - 7).pick(:target)
      return FLOOR unless previous_target

      done = WeeklyContribution.total_for(week_start - 7)
      [ round_up(next_target(previous_target, done)), FLOOR ].max
    end

    def self.next_target(previous_target, done)
      done >= previous_target ? done * GROWTH_FACTOR : (previous_target + done) / 2r
    end

    def self.round_up(target) = (target / STEP).ceil * STEP

    private_class_method :next_target, :round_up
  end
end
