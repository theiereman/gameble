class IndexAccountsIdentitiesOnClerkUserId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :accounts_identities, :clerk_user_id, algorithm: :concurrently
  end
end
