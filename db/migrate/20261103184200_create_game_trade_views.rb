# When a player last opened a trade, so that an answer they have not looked at yet can reach the bell.
class CreateGameTradeViews < ActiveRecord::Migration[8.1]
  def change
    create_table :game_trade_views do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :trade, null: false, index: false, foreign_key: { to_table: :game_trades, on_delete: :cascade }
      t.datetime :seen_at, null: false
      t.timestamps

      t.index %i[player_id trade_id], unique: true
    end
  end
end
