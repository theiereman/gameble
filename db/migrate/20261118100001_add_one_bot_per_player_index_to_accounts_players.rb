class AddOneBotPerPlayerIndexToAccountsPlayers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :accounts_players, :bot_of_id, unique: true, where: "bot_of_id IS NOT NULL",
      name: "index_accounts_players_one_bot_per_player", algorithm: :concurrently
  end
end
