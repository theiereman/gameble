# The trades screen finds a trade by its token: unique, built
# concurrently so the table stays writable (strong_migrations).
class IndexGameTradesOnToken < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_trades, :token, unique: true, algorithm: :concurrently
  end
end
