class AddWelcomePendingToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :welcome_pending, :boolean, default: false, null: false
  end
end
