class ValidateGameWeeklyContributionsTradesCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_weekly_contributions, name: "game_weekly_contributions_trades_check"
  end
end
