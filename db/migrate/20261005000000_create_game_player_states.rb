# One row of game state per player: the row later stories
# lock last (bank lock, holdings, then these rows) and add their columns to.
# It holds nothing else yet. Created at sign-up (Game::Handlers::
# PlayerRegistered) and backfilled for existing players by
# `game:backfill_player_states` (Game::BackfillPlayerStatesJob).
class CreateGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    create_table :game_player_states do |t|
      t.references :player, null: false, index: { unique: true }, foreign_key: { to_table: :accounts_players }
      t.timestamps
    end
  end
end
