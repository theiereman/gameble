class CreateGameMarketPendingWantedRefreshes < ActiveRecord::Migration[8.1]
  def change
    create_table :game_market_pending_wanted_refreshes, id: false do |t|
      t.references :player, null: false, index: { unique: true }, foreign_key: { to_table: :accounts_players }
    end
  end
end
