class IndexGamePacksOpenedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_packs, :opened_at, where: "opened_at IS NOT NULL",
      name: "index_game_packs_on_opened_at", algorithm: :concurrently
  end
end
