class ValidateGameFeedEntriesTrade < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :game_feed_entries, :game_trades, column: :trade_id
    validate_foreign_key :game_feed_entries, :accounts_players, column: :partner_id
    validate_foreign_key :game_feed_entries, :catalog_card_seasons, column: :partner_card_season_id
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_trade_check"
  end
end
