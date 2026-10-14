class CreateAccountsDataExports < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_data_exports do |t|
      t.references :player, null: false, index: { unique: true }, foreign_key: { to_table: :accounts_players }
      t.text :file, null: false
      t.timestamps
    end
  end
end
