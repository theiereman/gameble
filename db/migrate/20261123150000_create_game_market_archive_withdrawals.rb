# One Archive purchase: the copy a player bought from the Archives, at the price of the version in force. Kept when the player is deleted.
class CreateGameMarketArchiveWithdrawals < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_archive_withdrawals do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :card_season, null: false, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.references :settings, null: false, index: false, foreign_key: { to_table: :game_market_settings }
      t.string :purchase_token, null: false
      t.bigint :price, null: false
      t.datetime :created_at, null: false

      t.check_constraint "price > 0", name: "game_market_archive_withdrawals_price_check"
    end
  end
end
