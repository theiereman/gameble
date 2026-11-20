class CreateGameCapacitySlots < ActiveRecord::Migration[8.1]
  def change
    create_table :game_capacity_slots do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.string :kind, null: false
      t.integer :bought, null: false
      t.timestamps

      t.index %i[player_id kind], unique: true
      t.check_constraint "kind::text = 'goal'::text OR kind::text = 'custom_set'::text OR kind::text = 'deck'::text",
        name: "game_capacity_slots_kind_check"
      t.check_constraint "bought >= 1 AND bought <= 5 AND (kind::text <> 'deck'::text OR bought <= 2)",
        name: "game_capacity_slots_bought_check"
    end
  end
end
