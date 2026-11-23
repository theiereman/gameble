class AddOrderIndexToGameMarketNotices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_notices, :order_id, algorithm: :concurrently, if_not_exists: true
  end
end
