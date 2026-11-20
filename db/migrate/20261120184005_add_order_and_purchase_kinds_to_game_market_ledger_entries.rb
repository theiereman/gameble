class AddOrderAndPurchaseKindsToGameMarketLedgerEntries < ActiveRecord::Migration[8.1]
  OLD_KINDS = %w[mint stamp hold release purchase sale commission forfeit].freeze
  KINDS = (OLD_KINDS + %w[archive_purchase slot_purchase]).freeze

  def change
    add_column :game_market_ledger_entries, :order_id, :bigint
    add_foreign_key :game_market_ledger_entries, :game_market_orders, column: :order_id, validate: false
    add_check_constraint :game_market_ledger_entries, "listing_id IS NULL OR order_id IS NULL", name: "game_market_ledger_entries_one_subject_check",
      validate: false
    remove_check_constraint :game_market_ledger_entries, "kind ~ '^(#{OLD_KINDS.join("|")})$'", name: "game_market_ledger_entries_kind_check"
    add_check_constraint :game_market_ledger_entries, "kind ~ '^(#{KINDS.join("|")})$'", name: "game_market_ledger_entries_kind_check", validate: false
  end
end
