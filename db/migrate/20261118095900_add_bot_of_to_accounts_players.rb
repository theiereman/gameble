class AddBotOfToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :bot_of_id, :bigint, if_not_exists: true
  end
end
