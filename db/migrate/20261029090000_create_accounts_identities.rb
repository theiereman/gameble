class CreateAccountsIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_identities do |t|
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email_hash
      t.timestamps

      t.index [ :provider, :uid ], unique: true
      t.index :email_hash
      t.check_constraint "provider IN ('steam', 'discord', 'google', 'email')",
        name: "accounts_identities_provider_check", validate: false
    end
  end
end
