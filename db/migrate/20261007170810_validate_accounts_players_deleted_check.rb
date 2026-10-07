# Contract of account deletion: validates the check constraint added
# unvalidated, which takes no lock that blocks writes.
class ValidateAccountsPlayersDeletedCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_players, name: "accounts_players_deleted_check"
  end
end
