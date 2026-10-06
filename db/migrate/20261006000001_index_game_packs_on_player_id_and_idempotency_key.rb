# A pack's Idempotency-Key is unique per player (AD-23), among the packs
# that carry one: two requests with one key never open two packs. Built
# concurrently so the table stays writable (strong_migrations).
class IndexGamePacksOnPlayerIdAndIdempotencyKey < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_packs, [ :player_id, :idempotency_key ], unique: true, where: "idempotency_key IS NOT NULL",
      name: "index_game_packs_on_player_id_and_idempotency_key", algorithm: :concurrently
  end
end
