class ValidateGameFeedEntriesOrder < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :game_feed_entries, :game_market_orders, column: :order_id
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_sale_reference_check"
    remove_check_constraint :game_feed_entries, "(kind = 'sale') = (listing_id IS NOT NULL)", name: "game_feed_entries_sale_check"
  end
end
