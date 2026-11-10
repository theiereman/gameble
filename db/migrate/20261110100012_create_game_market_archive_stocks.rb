class CreateGameMarketArchiveStocks < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_archive_stocks do |t|
      t.references :card_season, null: false, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.integer :quantity, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :card_season_id, unique: true, name: "index_game_market_archive_stocks_uniqueness"
      t.check_constraint "quantity > 0", name: "game_market_archive_stocks_quantity_check"
    end
  end
end
