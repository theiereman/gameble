class RemoveOrderEndIndexFromGameMarketNotices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :game_market_notices, %i[player_id order_id], unique: true, algorithm: :concurrently, name: "index_game_market_notices_order_end",
      where: "kind IN ('order_served', 'order_expired')"
  end
end
