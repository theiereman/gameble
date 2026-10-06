# The hub's showcase (Game::NotablePull) reads a player's latest opened packs
# of a season: this partial index serves that read in order, without
# fetching and sorting every pack the player ever had. Built concurrently so
# the table stays writable (strong_migrations).
class IndexGamePacksOpened < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_packs, [ :player_id, :season_id, :opened_at ], order: { opened_at: :desc },
      where: "opened_at IS NOT NULL", name: "index_game_packs_opened", algorithm: :concurrently
  end
end
