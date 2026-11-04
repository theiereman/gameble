class ValidateAccountsIdentitiesProviderCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_identities, name: "accounts_identities_provider_check"
  end
end
