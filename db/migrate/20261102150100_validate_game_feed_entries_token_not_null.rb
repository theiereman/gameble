class ValidateGameFeedEntriesTokenNotNull < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_token_null"
    change_column_null :game_feed_entries, :token, false
    remove_check_constraint :game_feed_entries, name: "game_feed_entries_token_null"
  end

  def down
    add_check_constraint :game_feed_entries, "token IS NOT NULL", name: "game_feed_entries_token_null", validate: false
    change_column_null :game_feed_entries, :token, true
  end
end
