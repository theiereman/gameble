class AddRulesVersionToGameDuels < ActiveRecord::Migration[8.1]
  def change
    add_column :game_duels, :rules_version, :integer, null: false, default: 1
  end
end
