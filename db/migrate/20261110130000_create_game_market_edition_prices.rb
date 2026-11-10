# The average price of one card-season's recent sales, one row each. Written only by the market operations.
class CreateGameMarketEditionPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_edition_prices do |t|
      t.references :card_season, null: false, index: { unique: true }, foreign_key: { to_table: :catalog_card_seasons }
      t.bigint :average
      t.integer :sales_used, null: false, default: 0
      t.datetime :refreshed_at
      t.timestamps

      t.check_constraint "sales_used >= 0", name: "game_market_edition_prices_sales_used_check"
      t.check_constraint "average IS NULL OR average >= 0", name: "game_market_edition_prices_average_check"
      t.check_constraint "(average IS NULL) = (sales_used = 0)", name: "game_market_edition_prices_average_sales_check"
    end
  end
end
