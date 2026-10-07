# The activity feed (CAP-13, AD-10, AD-13, story 6.1): one row per card a
# pack-opened event puts in the feed, written by a handler in the opening's
# transaction. `notable` is a pull of Épique or better; the others are
# fillers, one per pack at most, for a quiet feed. Nothing about visibility
# is stored (AD-13): it is asked at render.
class CreateGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :game_feed_entries do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :pack, null: false, index: false, foreign_key: { to_table: :game_packs }
      t.bigint :card_season_id, null: false
      t.integer :position, null: false
      t.integer :rarity, null: false
      t.boolean :notable, null: false, default: true
      t.datetime :occurred_at, null: false
      t.timestamps
      t.index %i[pack_id position], unique: true
      t.index %i[notable occurred_at id]
      t.index :player_id
      t.check_constraint "rarity BETWEEN 1 AND 5", name: "game_feed_entries_rarity_check"
    end
  end
end
