class CreateGameCardBackUnlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :game_card_back_unlocks do |t|
      t.bigint :player_id, null: false
      t.string :back, null: false
      t.datetime :unlocked_at, null: false
      t.timestamps
      t.index %i[player_id back], unique: true
    end
  end
end
