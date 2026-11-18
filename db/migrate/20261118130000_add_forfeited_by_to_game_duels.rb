# The seat that gave up an active duel, whose opponent wins it.
class AddForfeitedByToGameDuels < ActiveRecord::Migration[8.1]
  def change
    add_column :game_duels, :forfeited_by, :string
    add_check_constraint :game_duels, "forfeited_by IS NULL OR (state = 'finished' AND forfeited_by IN ('challenger', 'opponent'))",
      name: "game_duels_forfeited_by_check", validate: false
  end
end
