# The cards a player chose to show on their profile, in their order.
class CreateGameShowcaseEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :game_showcase_entries do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :card_season, null: false, index: true, foreign_key: { to_table: :catalog_card_seasons }
      t.integer :position, null: false
      t.timestamps

      t.index %i[player_id card_season_id], unique: true
      t.check_constraint "position >= 0", name: "game_showcase_entries_position_check"
    end
  end
end
