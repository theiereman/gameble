class AddSteamLibrarySyncToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :steam_library_sync, :boolean, default: true, null: false
  end
end
