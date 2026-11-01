class RemoveGameTradesOneOpenPerPairIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :game_trades, %i[low_player_id high_player_id], unique: true, where: "status = 'open'",
      name: "index_game_trades_one_open_per_pair", algorithm: :concurrently
  end
end
