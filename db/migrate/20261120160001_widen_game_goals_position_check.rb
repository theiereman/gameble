class WidenGameGoalsPositionCheck < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :game_goals, "position BETWEEN 1 AND 5", name: "game_goals_position_check"
    add_check_constraint :game_goals, "position BETWEEN 1 AND 10", name: "game_goals_position_check", validate: false
  end
end
