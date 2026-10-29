class AddClerkUserIdToAccountsIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_identities, :clerk_user_id, :string
  end
end
