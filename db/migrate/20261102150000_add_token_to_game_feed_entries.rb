# A feed entry's public token: the address of its reactions, in place of its id.
class AddTokenToGameFeedEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :game_feed_entries, :token, :uuid
    change_column_default :game_feed_entries, :token, from: nil, to: -> { "gen_random_uuid()" }
    exec_update("UPDATE game_feed_entries SET token = gen_random_uuid() WHERE token IS NULL")
    add_check_constraint :game_feed_entries, "token IS NOT NULL", name: "game_feed_entries_token_null", validate: false
  end

  def down
    remove_check_constraint :game_feed_entries, name: "game_feed_entries_token_null"
    remove_column :game_feed_entries, :token
  end
end
