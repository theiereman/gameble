class DropGameSetCompletions < ActiveRecord::Migration[8.1]
  def change
    drop_table :game_set_completions do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.bigint :set_id, null: false
      t.datetime :completed_at, null: false
      t.timestamps
      t.index %i[player_id set_id], unique: true
    end
  end
end
