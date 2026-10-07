module Game
  # The weekly goal (CAP-12, AD-9): one row per week, holding its target and
  # the total of the week's contributions, which Game::SumWeeklyGoalJob keeps
  # up to date. A week starts on Monday 00:00 UTC.
  #
  # The target is the number of players active the previous week (at least
  # one pack opened) times PER_PLAYER, never below FLOOR: tuned in play.
  #
  # Written only through Game::SumWeeklyGoalJob (AD-3).
  class WeeklyGoal < ApplicationRecord
    self.table_name = "game_weekly_goals"

    PER_PLAYER = 50
    FLOOR = 200

    # The Monday (a Date) of the UTC week a time falls in.
    def self.week_start(time) = time.utc.to_date.beginning_of_week(:monday)

    # The target of the week starting on `week_start`, from the previous
    # week's contributions.
    def self.target_for(week_start)
      active = WeeklyContribution.where(week_start: week_start - 7, openings: 1..).count
      [ active * PER_PLAYER, FLOOR ].max
    end
  end
end
