# The weekly goal (CAP-12, AD-9, AD-10, story 6.3). A contribution is one row
# per player and week, unique, written by the player's own openings; the goal
# is one row per week holding the target and the total a periodic job sums
# from the contributions, so no row is written by every player.
class CreateGameWeeklyGoal < ActiveRecord::Migration[8.1]
  def change
    create_table :game_weekly_contributions do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.date :week_start, null: false
      t.integer :openings, null: false, default: 0
      t.timestamps
      t.index %i[player_id week_start], unique: true
      t.index :week_start
      t.check_constraint "openings >= 0", name: "game_weekly_contributions_openings_check"
    end

    create_table :game_weekly_goals do |t|
      t.date :week_start, null: false, index: { unique: true }
      t.integer :target, null: false
      t.integer :total, null: false, default: 0
      t.datetime :summed_at
      t.timestamps
      t.check_constraint "target > 0 AND total >= 0", name: "game_weekly_goals_figures_check"
    end
  end
end
