class AddOrderToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :game_feed_entries, :order_id, :bigint
    add_foreign_key :game_feed_entries, :game_market_orders, column: :order_id, validate: false

    add_check_constraint :game_feed_entries,
      "(kind = 'sale') = (listing_id IS NOT NULL OR order_id IS NOT NULL) AND (listing_id IS NULL OR order_id IS NULL)",
      name: "game_feed_entries_sale_reference_check", validate: false
  end
end
