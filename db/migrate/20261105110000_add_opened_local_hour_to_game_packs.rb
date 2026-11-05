class AddOpenedLocalHourToGamePacks < ActiveRecord::Migration[8.1]
  def change
    add_column :game_packs, :opened_local_hour, :integer, limit: 2
  end
end
