# Validates the role check constraint added without validation (strong_migrations).
class ValidateAccountsPlayersRoleCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_players, name: "accounts_players_role_check"
  end
end
