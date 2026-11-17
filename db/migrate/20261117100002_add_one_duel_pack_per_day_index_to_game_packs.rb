class AddOneDuelPackPerDayIndexToGamePacks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_packs, %i[player_id duel_day], unique: true, where: "duel_day IS NOT NULL",
      name: "index_game_packs_one_duel_pack_per_day", algorithm: :concurrently
  end
end
