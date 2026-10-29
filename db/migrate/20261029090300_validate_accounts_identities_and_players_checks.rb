class ValidateAccountsIdentitiesAndPlayersChecks < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_identities, name: "accounts_identities_provider_check"
    validate_check_constraint :accounts_players, name: "accounts_players_deleted_no_steam_id_check"
  end
end
