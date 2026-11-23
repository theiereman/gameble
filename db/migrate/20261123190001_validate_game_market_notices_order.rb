class ValidateGameMarketNoticesOrder < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :game_market_notices, :game_market_orders, column: :order_id
    validate_check_constraint :game_market_notices, name: "game_market_notices_subject_check"
    validate_check_constraint :game_market_notices, name: "game_market_notices_kind_check"
  end
end
