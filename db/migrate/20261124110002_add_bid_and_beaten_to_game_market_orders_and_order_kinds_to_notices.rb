class AddBidAndBeatenToGameMarketOrdersAndOrderKindsToNotices < ActiveRecord::Migration[8.1]
  OLD_STATUSES = %w[open served expired cancelled withdrawn].freeze
  STATUSES = (OLD_STATUSES + %w[bid beaten]).freeze
  OLD_KINDS = %w[outbid won sold unsold lead_voided withdrawn wanted order_served order_expired listed_above_order].freeze
  KINDS = (OLD_KINDS + %w[order_leads order_beaten]).freeze

  def change
    remove_check_constraint :game_market_orders, "status ~ '^(#{OLD_STATUSES.join("|")})$'", name: "game_market_orders_status_check"
    add_check_constraint :game_market_orders, "status ~ '^(#{STATUSES.join("|")})$'", name: "game_market_orders_status_check", validate: false
    remove_check_constraint :game_market_notices, "kind ~ '^(#{OLD_KINDS.join("|")})$'", name: "game_market_notices_kind_check"
    add_check_constraint :game_market_notices, "kind ~ '^(#{KINDS.join("|")})$'", name: "game_market_notices_kind_check", validate: false
  end
end
