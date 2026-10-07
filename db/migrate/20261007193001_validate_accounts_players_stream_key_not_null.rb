class ValidateAccountsPlayersStreamKeyNotNull < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :accounts_players, name: "accounts_players_stream_key_null"
    change_column_null :accounts_players, :stream_key, false
    remove_check_constraint :accounts_players, name: "accounts_players_stream_key_null"
  end

  def down
    add_check_constraint :accounts_players, "stream_key IS NOT NULL", name: "accounts_players_stream_key_null", validate: false
    change_column_null :accounts_players, :stream_key, true
  end
end
