# The kind of a feed entry (CAP-13, story 6.2): a pull, a first discovery, a
# trade or a repost, so the feed's type filters can read one kind. Expand
# (AD-21): a constant default with NOT NULL is a metadata-only change on
# PostgreSQL 11+, so every existing entry becomes a pull without a backfill;
# the check constraint is added unvalidated, validated by the next migration.
class AddKindToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :game_feed_entries, :kind, :string, default: "pull", null: false
    add_check_constraint :game_feed_entries, "kind IN ('pull', 'discovery', 'trade', 'repost')",
      name: "game_feed_entries_kind_check", validate: false
  end
end
