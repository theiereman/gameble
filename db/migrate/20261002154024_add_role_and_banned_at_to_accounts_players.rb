# Staff roles and bans (AD-14, CAP-15). A visitor is the absence of a player;
# a player's role is player, moderator or administrator. A ban is the time it
# took effect. The check constraint is validated in the next migration so
# adding it does not block the table (strong_migrations).
class AddRoleAndBannedAtToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :role, :string, null: false, default: "player"
    add_column :accounts_players, :banned_at, :datetime

    add_check_constraint :accounts_players, "role = 'player' OR role = 'moderator' OR role = 'administrator'",
      name: "accounts_players_role_check", validate: false
  end
end
