# Set completions: one row per player and
# set, the first time the player holds every card of it, unique in the
# database. Its insert decides that Game::SetCompleted is published, once.
class CreateGameSetCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_set_completions do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.bigint :set_id, null: false
      t.datetime :completed_at, null: false
      t.timestamps
      t.index %i[player_id set_id], unique: true
    end
  end
end
