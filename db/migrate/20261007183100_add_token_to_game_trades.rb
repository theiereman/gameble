# A trade's public token (AD-15, story 5.6): the trades screen addresses a
# trade by it, never by its id. Expand: the column is added nullable, the
# trades already stored get a token like has_secure_token's (24 base58
# characters), and a NOT NULL check is added unvalidated; the next
# migrations validate it and index the token.
class AddTokenToGameTrades < ActiveRecord::Migration[8.1]
  def up
    add_column :game_trades, :token, :string
    select_values("SELECT id FROM game_trades WHERE token IS NULL").each do |id|
      exec_update("UPDATE game_trades SET token = $1 WHERE id = $2", "SQL", [ SecureRandom.base58(24), id ])
    end
    add_check_constraint :game_trades, "token IS NOT NULL", name: "game_trades_token_null", validate: false
  end

  def down
    remove_check_constraint :game_trades, name: "game_trades_token_null"
    remove_column :game_trades, :token
  end
end
