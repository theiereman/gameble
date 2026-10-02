# The pack bank and the owned cards (CAP-4, AD-6, AD-7).
#
# A pack is one row with its cards pre-drawn, in order, so opening reads one
# row. Bonus and reward packs are rows of the same table. Addressed in URLs by
# a random token (AD-15).
#
# Owned cards are counted: one row per player and card-season, with a
# quantity and a reserved count (AD-6).
class CreateGamePacksAndHoldings < ActiveRecord::Migration[8.1]
  def change
    create_table :game_packs do |t|
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.string :token, null: false
      t.string :kind, null: false
      t.references :season, null: false, foreign_key: { to_table: :catalog_seasons }
      t.bigint :card_season_ids, array: true, null: false
      t.datetime :available_at, null: false
      t.datetime :opened_at
      t.timestamps

      t.check_constraint "kind = 'regular' OR kind = 'bonus' OR kind = 'reward'", name: "game_packs_kind_check"
      t.index :token, unique: true
      # The player's unopened packs, oldest first: the next one to open.
      t.index [ :player_id, :available_at, :id ], where: "opened_at IS NULL", name: "index_game_packs_unopened"
    end

    create_table :game_holdings do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :card_season, null: false, foreign_key: { to_table: :catalog_card_seasons }
      t.integer :quantity, null: false, default: 0
      t.integer :reserved, null: false, default: 0
      t.timestamps

      t.check_constraint "quantity >= reserved AND reserved >= 0", name: "game_holdings_quantity_check"
      t.index [ :player_id, :card_season_id ], unique: true
    end
  end
end
