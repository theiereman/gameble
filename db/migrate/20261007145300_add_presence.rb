# Friends' presence (CAP-21, AD-24): the time a player was last seen, on
# their account, written by a throttled job (Accounts::NoteLastSeenJob); and
# their latest game action with its time, on their game state row, written
# by a Game handler (Game::Handlers::PlayerActivity). All nullable: a player
# never seen or who never acted has none.
class AddPresence < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :last_seen_at, :datetime
    add_column :game_player_states, :last_activity, :string
    add_column :game_player_states, :last_activity_at, :datetime
  end
end
