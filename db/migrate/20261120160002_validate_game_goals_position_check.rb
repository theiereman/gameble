class ValidateGameGoalsPositionCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_goals, name: "game_goals_position_check"
  end
end
