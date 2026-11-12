class CreateGameMarketChartPublications < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_chart_publications do |t|
      t.string :kind, null: false, index: { unique: true }
      t.datetime :published_at
      t.datetime :unpublished_at
      t.references :changed_by, null: false, foreign_key: { to_table: :accounts_players }
      t.timestamps

      t.check_constraint "kind ~ '^(reactor|rarity_prices|edition_sales)$'", name: "game_market_chart_publications_kind_check"
    end
  end
end
