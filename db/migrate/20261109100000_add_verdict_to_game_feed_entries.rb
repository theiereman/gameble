class AddVerdictToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost' OR kind = 'set'",
      name: "game_feed_entries_kind_check"
    add_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost' OR kind = 'set' OR kind = 'verdict'",
      name: "game_feed_entries_kind_check", validate: false

    remove_check_constraint :game_feed_entries,
      "(kind = 'set') = (set_id IS NOT NULL AND tier IS NOT NULL AND set_count IS NOT NULL) " \
      "AND (kind = 'set') = (card_season_id IS NULL) AND (kind = 'set') = (rarity IS NULL)",
      name: "game_feed_entries_set_check"
    add_check_constraint :game_feed_entries,
      "(kind = 'set') = (set_id IS NOT NULL AND tier IS NOT NULL AND set_count IS NOT NULL) " \
      "AND (kind = 'set' OR kind = 'verdict') = (card_season_id IS NULL) AND (kind = 'set' OR kind = 'verdict') = (rarity IS NULL)",
      name: "game_feed_entries_set_check", validate: false
  end
end
