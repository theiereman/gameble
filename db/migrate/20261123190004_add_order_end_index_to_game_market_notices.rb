class AddOrderEndIndexToGameMarketNotices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_notices, %i[player_id order_id], unique: true, where: "(kind)::text = ANY (ARRAY[('order_served'::character varying)::text, ('order_expired'::character varying)::text])",
      algorithm: :concurrently, name: "index_game_market_notices_order_end"
  end
end
