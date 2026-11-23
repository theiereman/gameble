class AddListedAboveOrderIndexToGameMarketNotices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_notices, %i[player_id order_id], unique: true, where: "kind = 'listed_above_order'", algorithm: :concurrently,
      name: "index_game_market_notices_listed_above_order"
  end
end
