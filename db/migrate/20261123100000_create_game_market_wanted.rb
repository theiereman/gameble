class CreateGameMarketWanted < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_wanted do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :card, null: false, foreign_key: { to_table: :catalog_cards }
      t.string :reason, null: false
      t.integer :rarities, limit: 2, array: true
      t.index [ :player_id, :card_id, :reason ], unique: true, name: "index_game_market_wanted_uniqueness"
      t.check_constraint "reason ~ '^(goal|order)$'", name: "game_market_wanted_reason_check"
      t.check_constraint "(reason = 'goal') = (rarities IS NULL)", name: "game_market_wanted_rarities_check"
    end
  end
end
