# Players: a Steam id and a public random token. No name,
# avatar or password is stored.
class CreateAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_players do |t|
      t.string :steam_id, null: false
      t.string :token, null: false
      t.timestamps
    end

    add_index :accounts_players, :steam_id, unique: true
    add_index :accounts_players, :token, unique: true
  end
end
