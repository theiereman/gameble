class AddLastExportedAtToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :last_exported_at, :datetime
  end
end
