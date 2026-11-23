class AddCardSeasonIndexToGameMarketArchiveWithdrawals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_archive_withdrawals, :card_season_id, algorithm: :concurrently
  end
end
