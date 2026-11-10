# The economy's figures, one row per UTC day, written by the nightly job and read only by the back-office. A missing figure is null, never 0.
class CreateGameMarketDailySnapshots < ActiveRecord::Migration[8.1]
  RARITIES = %w[common uncommon rare epic legendary].freeze

  def change
    create_table :game_market_daily_snapshots do |t|
      t.date :day, null: false, index: { unique: true }
      t.bigint :created, null: false
      t.bigint :destroyed_total, null: false
      t.bigint :forfeited, null: false
      t.bigint :circulation, null: false
      t.bigint :picoins_per_active_player
      t.bigint :median_daily_earnings
      RARITIES.each { |rarity| t.bigint :"average_price_#{rarity}" }
      t.integer :top_share_basis_points
      t.boolean :reconciliation_balanced, null: false
      t.integer :wallet_differences, null: false, default: 0
      t.bigint :circulation_difference, null: false, default: 0
      t.datetime :created_at, null: false

      t.check_constraint "created >= 0 AND destroyed_total >= 0 AND forfeited >= 0 AND forfeited <= destroyed_total", name: "game_market_daily_snapshots_flows_check"
      t.check_constraint "top_share_basis_points IS NULL OR top_share_basis_points BETWEEN 0 AND 10000", name: "game_market_daily_snapshots_top_share_check"
    end
  end
end
