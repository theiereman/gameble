class CreateGameMarketAltSignals < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_alt_signals do |t|
      t.references :account, null: false, foreign_key: { to_table: :accounts_players }
      t.string :signal, null: false
      t.references :other_account, foreign_key: { to_table: :accounts_players }
      t.jsonb :facts, null: false, default: {}
      t.datetime :refreshed_at, null: false
    end
  end
end
