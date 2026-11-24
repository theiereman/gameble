class ValidateGameMarketOrdersStatusAndNoticesKindChecks < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_market_orders, name: "game_market_orders_status_check"
    validate_check_constraint :game_market_notices, name: "game_market_notices_kind_check"
  end
end
