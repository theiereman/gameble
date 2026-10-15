# The tiers of a set a player has reached, one row per player, set and
# tier, with how it was reached: by an opening (its pack) or by a trade.
class CreateGameSetTiers < ActiveRecord::Migration[8.1]
  def change
    create_table :game_set_tiers do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.bigint :set_id, null: false
      t.string :tier, null: false
      t.string :reached_by, null: false
      t.references :pack, null: true, index: true, foreign_key: { to_table: :game_packs, on_delete: :cascade }
      t.datetime :reached_at, null: false
      t.timestamps

      t.index %i[player_id set_id tier], unique: true
      t.check_constraint "tier = 'bronze' OR tier = 'silver' OR tier = 'gold' OR tier = 'complete'", name: "game_set_tiers_tier_check"
      t.check_constraint "reached_by = 'pack' OR reached_by = 'trade'", name: "game_set_tiers_reached_by_check"
      t.check_constraint "(reached_by = 'pack') = (pack_id IS NOT NULL)", name: "game_set_tiers_pack_check"
    end
  end
end
