class CreateAccountsPushDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_push_devices do |t|
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.string :platform, null: false
      t.string :token, null: false
      t.string :locale, null: false
      t.timestamps

      t.index :token, unique: true
      t.check_constraint "platform ~ '^(apple|google)$'", name: "accounts_push_devices_platform_check", validate: false
      t.check_constraint "char_length(token) <= 4096", name: "accounts_push_devices_token_length_check", validate: false
    end
  end
end
