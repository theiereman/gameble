class RenameWidenedOrderEndIndexOfGameMarketNotices < ActiveRecord::Migration[8.1]
  def change
    rename_index :game_market_notices, "index_game_market_notices_order_end_widened", "index_game_market_notices_order_end"
  end
end
