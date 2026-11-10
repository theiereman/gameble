# One copy offered at auction: its price, its end, its leader and how it closed. Written only by the market operations.
class CreateGameMarketListings < ActiveRecord::Migration[8.1]
  STATUSES = %w[open sold unsold cancelled withdrawn].freeze

  def change
    create_table :game_market_listings do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :seller, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :card_season, null: false, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.references :settings, null: false, index: false, foreign_key: { to_table: :game_market_settings }
      t.bigint :starting_price, null: false
      t.bigint :buy_now_price
      t.integer :duration_hours, null: false
      t.datetime :ends_at, null: false
      t.bigint :current_price, null: false
      t.references :leader, index: false, foreign_key: { to_table: :accounts_players }
      t.bigint :leader_maximum
      t.datetime :sold_at
      t.bigint :final_price
      t.string :status, null: false, default: "open"
      t.timestamps

      t.check_constraint "status IN (#{STATUSES.map { |status| "'#{status}'" }.join(", ")})", name: "game_market_listings_status_check"
      t.check_constraint "starting_price > 0", name: "game_market_listings_starting_price_check"
      t.check_constraint "buy_now_price IS NULL OR buy_now_price > starting_price", name: "game_market_listings_buy_now_check"
      t.check_constraint "current_price >= starting_price", name: "game_market_listings_current_price_check"
      t.check_constraint "(leader_id IS NULL) = (leader_maximum IS NULL)", name: "game_market_listings_leader_check"
      t.check_constraint "(sold_at IS NULL) = (final_price IS NULL)", name: "game_market_listings_sold_check"
      t.check_constraint "duration_hours > 0", name: "game_market_listings_duration_check"
    end
  end
end
