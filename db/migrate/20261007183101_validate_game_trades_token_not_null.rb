# Contract of the trade token: validates the check added unvalidated, which
# blocks no write, then makes the column NOT NULL (PostgreSQL uses the
# validated check and skips the scan) and drops the check.
class ValidateGameTradesTokenNotNull < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :game_trades, name: "game_trades_token_null"
    change_column_null :game_trades, :token, false
    remove_check_constraint :game_trades, name: "game_trades_token_null"
  end

  def down
    add_check_constraint :game_trades, "token IS NOT NULL", name: "game_trades_token_null", validate: false
    change_column_null :game_trades, :token, true
  end
end
