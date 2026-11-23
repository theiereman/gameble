class AddOrderToGameMarketNotices < ActiveRecord::Migration[8.1]
  OLD_KINDS = %w[outbid won sold unsold lead_voided withdrawn wanted].freeze
  KINDS = (OLD_KINDS + %w[order_served order_expired listed_above_order]).freeze

  def change
    add_column :game_market_notices, :order_id, :bigint
    add_foreign_key :game_market_notices, :game_market_orders, column: :order_id, validate: false
    change_column_null :game_market_notices, :listing_id, true
    add_check_constraint :game_market_notices, "listing_id IS NOT NULL OR order_id IS NOT NULL", name: "game_market_notices_subject_check", validate: false
    remove_check_constraint :game_market_notices, "kind ~ '^(#{OLD_KINDS.join("|")})$'", name: "game_market_notices_kind_check"
    add_check_constraint :game_market_notices, "kind ~ '^(#{KINDS.join("|")})$'", name: "game_market_notices_kind_check", validate: false
  end
end
