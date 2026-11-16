class CreateGameBellReads < ActiveRecord::Migration[8.1]
  def change
    create_table :game_bell_reads do |t|
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }, index: false
      t.string :key, null: false
      t.datetime :read_at, null: false
      t.timestamps
    end
    add_index :game_bell_reads, %i[player_id key], unique: true
    add_index :game_bell_reads, %i[player_id read_at]
  end
end
