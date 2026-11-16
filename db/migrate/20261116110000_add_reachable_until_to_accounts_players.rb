class AddReachableUntilToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :reachable_until, :datetime
  end
end
