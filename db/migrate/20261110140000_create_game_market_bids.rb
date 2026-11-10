# One validated bid on a listing: the maximum held, the price it left and how it ended. Written only by the market operations.
class CreateGameMarketBids < ActiveRecord::Migration[8.1]
  OUTCOMES = %w[leading outbid beaten raise won lost voided].freeze

  def change
    create_table :game_market_bids do |t|
      t.references :listing, null: false, index: false, foreign_key: { to_table: :game_market_listings }
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.bigint :maximum, null: false
      t.bigint :price_after, null: false
      t.string :outcome, null: false
      t.datetime :extended_until
      t.datetime :created_at, null: false

      t.check_constraint "outcome IN (#{OUTCOMES.map { |outcome| "'#{outcome}'" }.join(", ")})", name: "game_market_bids_outcome_check"
      t.check_constraint "maximum > 0", name: "game_market_bids_maximum_check"
      t.check_constraint "price_after > 0", name: "game_market_bids_price_after_check"
    end
  end
end
