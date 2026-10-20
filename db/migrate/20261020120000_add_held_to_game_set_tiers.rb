class AddHeldToGameSetTiers < ActiveRecord::Migration[8.1]
  def change
    add_column :game_set_tiers, :held, :integer
  end
end
