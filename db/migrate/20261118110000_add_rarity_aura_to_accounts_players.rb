class AddRarityAuraToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :rarity_aura, :boolean, default: true, null: false
  end
end
