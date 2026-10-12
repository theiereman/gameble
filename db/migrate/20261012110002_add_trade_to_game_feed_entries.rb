class AddTradeToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :game_feed_entries, :trade_id, :bigint
    add_column :game_feed_entries, :partner_id, :bigint
    add_column :game_feed_entries, :partner_card_season_id, :bigint
    add_foreign_key :game_feed_entries, :game_trades, column: :trade_id, validate: false
    add_foreign_key :game_feed_entries, :accounts_players, column: :partner_id, validate: false
    add_foreign_key :game_feed_entries, :catalog_card_seasons, column: :partner_card_season_id, validate: false
    add_check_constraint :game_feed_entries,
      "(kind = 'trade') = (trade_id IS NOT NULL AND partner_id IS NOT NULL AND partner_card_season_id IS NOT NULL)",
      name: "game_feed_entries_trade_check", validate: false
  end
end
