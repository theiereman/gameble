# One line a player is told about a listing: the latest thing that happened to them on it. Written only by the market handlers.
class CreateGameMarketNotices < ActiveRecord::Migration[8.1]
  KINDS = %w[outbid won sold unsold bought_over lead_voided withdrawn].freeze

  def change
    create_table :game_market_notices do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :listing, null: false, index: false, foreign_key: { to_table: :game_market_listings }
      t.string :kind, null: false
      t.references :other_player, index: false, foreign_key: { to_table: :accounts_players }
      t.bigint :amount
      t.datetime :noticed_at, null: false

      t.check_constraint "kind IN (#{KINDS.map { |kind| "'#{kind}'" }.join(", ")})", name: "game_market_notices_kind_check"
      t.check_constraint "amount IS NULL OR amount >= 0", name: "game_market_notices_amount_check"
    end
  end
end
