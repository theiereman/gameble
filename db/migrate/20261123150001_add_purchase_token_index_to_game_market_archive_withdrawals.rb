class AddPurchaseTokenIndexToGameMarketArchiveWithdrawals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_archive_withdrawals, %i[player_id purchase_token], unique: true, algorithm: :concurrently,
      name: "index_game_market_archive_withdrawals_uniqueness"
  end
end
