class AddPracticeToGameDuels < ActiveRecord::Migration[8.1]
  def change
    add_column :game_duels, :practice, :boolean, default: false, null: false
  end
end
