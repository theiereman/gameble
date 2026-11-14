class ValidateGameMarketNoticesWanted < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_market_notices, name: "game_market_notices_kind_check"
  end
end
