# The first reaction of each player to a feed entry, kept when the reaction is withdrawn, so that only a new reactor reaches the bell again.
class CreateGameReactionNotices < ActiveRecord::Migration[8.1]
  def change
    create_table :game_reaction_notices do |t|
      t.references :feed_entry, null: false, index: false, foreign_key: { to_table: :game_feed_entries, on_delete: :cascade }
      t.references :reactor, null: false, foreign_key: { to_table: :accounts_players }
      t.timestamps

      t.index %i[feed_entry_id reactor_id], unique: true
    end
  end
end
