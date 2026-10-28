class ValidateGameSetTiersReachedByValuesCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_set_tiers, name: "game_set_tiers_reached_by_values_check"
  end
end
