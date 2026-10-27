# The player's Steam persona name, read from Steam at each
# sign-in and shown as the title of their public profile. Nullable: a player
# whose name Steam never gave keeps none. Personal data: the export and the
# deletion of an account include it.
class AddPersonaNameToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :persona_name, :string
  end
end
