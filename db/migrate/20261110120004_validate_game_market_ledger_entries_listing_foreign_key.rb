class ValidateGameMarketLedgerEntriesListingForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :game_market_ledger_entries, :game_market_listings, column: :listing_id
  end
end
