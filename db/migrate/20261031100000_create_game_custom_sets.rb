# The sets a player gathers themselves: a named `custom` set, or the one
# `steam_library` set listing the catalog games their Steam library holds.
# A set lists games (catalog cards), never card-seasons.
class CreateGameCustomSets < ActiveRecord::Migration[8.1]
  def change
    create_table :game_custom_sets do |t|
      t.references :player, null: false, index: true, foreign_key: { to_table: :accounts_players }
      t.string :token, null: false, index: { unique: true }
      t.string :kind, null: false
      t.string :name
      t.datetime :synced_at
      t.datetime :library_private_since
      t.timestamps

      t.index :player_id, unique: true, where: "kind = 'steam_library'", name: "index_game_custom_sets_one_library_per_player"
      t.index "player_id, lower(name)", unique: true, where: "kind = 'custom'", name: "index_game_custom_sets_on_player_id_and_lower_name"
      t.check_constraint "kind = 'custom' OR kind = 'steam_library'", name: "game_custom_sets_kind_check"
      t.check_constraint "kind <> 'custom' OR (name IS NOT NULL AND char_length(name) BETWEEN 1 AND 40)", name: "game_custom_sets_name_check"
      t.check_constraint "kind <> 'custom' OR (synced_at IS NULL AND library_private_since IS NULL)", name: "game_custom_sets_sync_check"
    end

    create_table :game_custom_set_games do |t|
      t.references :custom_set, null: false, index: false, foreign_key: { to_table: :game_custom_sets, on_delete: :cascade }
      t.references :card, null: false, index: true, foreign_key: { to_table: :catalog_cards }
      t.timestamps

      t.index %i[custom_set_id card_id], unique: true
    end
  end
end
