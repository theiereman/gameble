class AddOneSettlementEntryPerPlayerToGameMarketLedgerEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_market_ledger_entries, %i[listing_id player_id kind], unique: true, algorithm: :concurrently,
      where: "kind = 'stamp' OR kind = 'purchase' OR kind = 'sale' OR kind = 'commission'",
      name: "index_game_market_ledger_entries_one_settlement"
  end
end
