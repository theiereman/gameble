class AddOrderDurationDaysToGameMarketSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :game_market_settings, :order_duration_days, :integer, null: false, default: 7
  end
end
