# The daily bonus: one claim per player and UTC day, unique in
# the database, pointing at the bonus pack it granted.
class CreateGameDailyBonusClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :game_daily_bonus_claims do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.date :day, null: false
      t.references :pack, null: false, foreign_key: { to_table: :game_packs }
      t.timestamps

      t.index [ :player_id, :day ], unique: true
    end
  end
end
