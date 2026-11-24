class AddPlayerTimeIndexToGameMarketArchiveWithdrawals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_archive_withdrawals, %i[player_id created_at], algorithm: :concurrently, name: "index_game_market_archive_withdrawals_on_player_and_time"
  end
end
