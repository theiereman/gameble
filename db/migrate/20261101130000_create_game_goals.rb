# The sets a player aims at: up to five numbered goals, each on a game set
# (by kind and key, so it follows the set from season to season) or on one
# of the player's custom sets, which takes its goal with it when deleted.
class CreateGameGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :game_goals do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.integer :position, null: false
      t.string :set_kind
      t.string :set_key
      t.references :custom_set, index: { unique: true, where: "custom_set_id IS NOT NULL" },
        foreign_key: { to_table: :game_custom_sets, on_delete: :cascade }
      t.timestamps

      t.index %i[player_id position], unique: true
      t.index %i[player_id set_kind set_key], unique: true, where: "set_kind IS NOT NULL", name: "index_game_goals_on_player_id_and_game_set"
      t.check_constraint "position BETWEEN 1 AND 5", name: "game_goals_position_check"
      t.check_constraint "(custom_set_id IS NULL) = (set_kind IS NOT NULL) AND (set_kind IS NULL) = (set_key IS NULL)",
        name: "game_goals_target_check"
      t.check_constraint "set_kind IS NULL OR set_kind = 'theme' OR set_kind = 'franchise' OR set_kind = 'studio' " \
        "OR set_kind = 'hall_of_fame' OR set_kind = 'ufo'", name: "game_goals_set_kind_check"
    end
  end
end
