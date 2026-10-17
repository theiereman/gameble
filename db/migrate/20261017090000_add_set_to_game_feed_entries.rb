# A set entry names the set and the tier a player reached, with no card.
class AddSetToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :game_feed_entries, :set_id, :bigint
    add_column :game_feed_entries, :tier, :string
    add_column :game_feed_entries, :set_count, :integer
    change_column_null :game_feed_entries, :card_season_id, true
    change_column_null :game_feed_entries, :rarity, true

    remove_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost'",
      name: "game_feed_entries_kind_check"
    add_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost' OR kind = 'set'",
      name: "game_feed_entries_kind_check", validate: false
    add_check_constraint :game_feed_entries,
      "(kind = 'set') = (set_id IS NOT NULL AND tier IS NOT NULL AND set_count IS NOT NULL) " \
      "AND (kind = 'set') = (card_season_id IS NULL) AND (kind = 'set') = (rarity IS NULL)",
      name: "game_feed_entries_set_check", validate: false
    add_check_constraint :game_feed_entries,
      "(tier IS NULL OR tier = 'bronze' OR tier = 'silver' OR tier = 'gold' OR tier = 'complete') " \
      "AND (set_count IS NULL OR set_count > 0)",
      name: "game_feed_entries_tier_check", validate: false
  end
end
