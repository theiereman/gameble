# The player's Steam persona name (CAP-8, story 4.4), read from Steam at each
# sign-in and shown as the title of their public profile. Nullable: a player
# whose name Steam never gave keeps none. Personal data: the export and the
# deletion of an account (epic 7) include it.
class AddPersonaNameToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :persona_name, :string
  end
end
