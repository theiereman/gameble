# A player's reaction to a feed entry: one of five fixed kinds, one per player
# and entry. Only the counts are ever shown.
class CreateGameFeedReactions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_feed_reactions do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :feed_entry, null: false, index: false, foreign_key: { to_table: :game_feed_entries, on_delete: :cascade }
      t.string :kind, null: false
      t.timestamps

      t.index %i[player_id feed_entry_id], unique: true
      t.check_constraint "kind IN ('thumb', 'heart', 'gg', 'wow', 'middle_finger')", name: "game_feed_reactions_kind_check"
    end
  end
end
