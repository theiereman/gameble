class CreateGameMarketTiedAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_tied_accounts do |t|
      t.references :low_account, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :high_account, null: false, foreign_key: { to_table: :accounts_players }
      t.string :signal, null: false
      t.jsonb :facts, null: false, default: {}
      t.datetime :refreshed_at, null: false
      t.index [ :low_account_id, :high_account_id, :signal ], unique: true, name: "index_game_market_tied_accounts_uniqueness"
      t.check_constraint "low_account_id < high_account_id", name: "game_market_tied_accounts_order_check"
    end
  end
end
