class AllowTheAllocationInGameSetTiersReachedBy < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_check_constraint :game_set_tiers, "reached_by::text = 'pack'::text OR reached_by::text = 'trade'::text", name: "game_set_tiers_reached_by_check" }
    add_check_constraint :game_set_tiers, "reached_by = 'pack' OR reached_by = 'trade' OR reached_by = 'allocation'", name: "game_set_tiers_reached_by_values_check", validate: false
  end
end
