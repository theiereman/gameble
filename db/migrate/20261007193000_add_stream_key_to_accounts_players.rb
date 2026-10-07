class AddStreamKeyToAccountsPlayers < ActiveRecord::Migration[8.1]
  def up
    add_column :accounts_players, :stream_key, :uuid
    change_column_default :accounts_players, :stream_key, from: nil, to: -> { "gen_random_uuid()" }
    exec_update("UPDATE accounts_players SET stream_key = gen_random_uuid() WHERE stream_key IS NULL")
    add_check_constraint :accounts_players, "stream_key IS NOT NULL", name: "accounts_players_stream_key_null", validate: false
  end

  def down
    remove_check_constraint :accounts_players, name: "accounts_players_stream_key_null"
    remove_column :accounts_players, :stream_key
  end
end
