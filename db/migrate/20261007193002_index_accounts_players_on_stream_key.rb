class IndexAccountsPlayersOnStreamKey < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :accounts_players, :stream_key, unique: true, algorithm: :concurrently
  end
end
