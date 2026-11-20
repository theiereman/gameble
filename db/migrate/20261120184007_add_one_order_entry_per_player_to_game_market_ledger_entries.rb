class AddOneOrderEntryPerPlayerToGameMarketLedgerEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_ledger_entries, %i[order_id player_id kind], unique: true, where: "order_id IS NOT NULL", algorithm: :concurrently,
      name: "index_game_market_ledger_entries_one_order_entry"
  end
end
