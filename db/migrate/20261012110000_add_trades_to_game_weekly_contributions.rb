class AddTradesToGameWeeklyContributions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_weekly_contributions, :trades, :integer, default: 0, null: false
    add_check_constraint :game_weekly_contributions, "trades >= 0", name: "game_weekly_contributions_trades_check", validate: false
  end
end
