# Contract of the visibility column: validates the check constraint added
# unvalidated, which takes no lock that blocks writes.
class ValidateAccountsPlayersVisibilityCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_players, name: "accounts_players_visibility_check"
  end
end
