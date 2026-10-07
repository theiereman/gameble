# Contract of the feed entries' kind column: validates the check constraint
# added unvalidated, which takes no lock that blocks writes.
class ValidateGameFeedEntriesKindCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_kind_check"
  end
end
