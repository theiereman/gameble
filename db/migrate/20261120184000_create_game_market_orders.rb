# A standing offer to buy one card at a price until it expires, served by a seller with one copy. Written only by the market operations.
class CreateGameMarketOrders < ActiveRecord::Migration[8.1]
  STATUSES = %w[open served expired cancelled withdrawn].freeze
  SERVED_COLUMNS = %w[seller_id served_card_season_id served_at average_after_sale].freeze

  def change
    create_table :game_market_orders do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.references :card, null: false, index: false, foreign_key: { to_table: :catalog_cards }
      t.references :settings, null: false, index: false, foreign_key: { to_table: :game_market_settings }
      t.bigint :price, null: false
      t.string :status, null: false, default: "open"
      t.datetime :expires_at, null: false
      t.references :seller, index: false, foreign_key: { to_table: :accounts_players }
      t.references :served_card_season, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.datetime :served_at
      t.bigint :average_after_sale
      t.timestamps

      t.check_constraint "status ~ '^(#{STATUSES.join("|")})$'", name: "game_market_orders_status_check"
      t.check_constraint "price > 0", name: "game_market_orders_price_check"
      t.check_constraint SERVED_COLUMNS.map { "(#{it} IS NOT NULL) = (status = 'served')" }.join(" AND "), name: "game_market_orders_served_check"
    end
  end
end
