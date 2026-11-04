class AddAppleToAccountsIdentitiesProviders < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :accounts_identities, "provider::text ~ '^(steam|discord|google|email)$'::text",
      name: "accounts_identities_provider_check"
    add_check_constraint :accounts_identities, "provider ~ '^(steam|apple|discord|google|email)$'",
      name: "accounts_identities_provider_check", validate: false
  end
end
