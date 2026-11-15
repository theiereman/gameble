class AddDuelStatsToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    change_column_null :game_feed_entries, :player_id, true

    remove_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost' OR kind = 'set' OR kind = 'verdict' OR kind = 'sale'",
      name: "game_feed_entries_kind_check"
    add_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost' OR kind = 'set' OR kind = 'verdict' OR kind = 'sale' " \
      "OR kind = 'duel_stats'",
      name: "game_feed_entries_kind_check", validate: false

    remove_check_constraint :game_feed_entries,
      "(kind = 'set') = (set_id IS NOT NULL AND tier IS NOT NULL AND set_count IS NOT NULL) " \
      "AND (kind = 'set' OR kind = 'verdict') = (card_season_id IS NULL) AND (kind = 'set' OR kind = 'verdict') = (rarity IS NULL)",
      name: "game_feed_entries_set_check"
    add_check_constraint :game_feed_entries,
      "(kind = 'set') = (set_id IS NOT NULL AND tier IS NOT NULL AND set_count IS NOT NULL) " \
      "AND (kind = 'set' OR kind = 'verdict' OR kind = 'duel_stats') = (card_season_id IS NULL) " \
      "AND (kind = 'set' OR kind = 'verdict' OR kind = 'duel_stats') = (rarity IS NULL)",
      name: "game_feed_entries_set_check", validate: false

    add_check_constraint :game_feed_entries,
      "(kind = 'duel_stats') = (player_id IS NULL) AND (kind = 'duel_stats') = (moves IS NOT NULL)",
      name: "game_feed_entries_duel_stats_check", validate: false
  end
end
