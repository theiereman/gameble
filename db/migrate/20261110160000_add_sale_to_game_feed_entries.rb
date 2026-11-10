class AddSaleToGameFeedEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :game_feed_entries, :listing_id, :bigint

    remove_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost' OR kind = 'set' OR kind = 'verdict'",
      name: "game_feed_entries_kind_check"
    add_check_constraint :game_feed_entries,
      "kind = 'pull' OR kind = 'discovery' OR kind = 'trade' OR kind = 'repost' OR kind = 'set' OR kind = 'verdict' OR kind = 'sale'",
      name: "game_feed_entries_kind_check", validate: false

    add_check_constraint :game_feed_entries, "(kind = 'sale') = (listing_id IS NOT NULL)",
      name: "game_feed_entries_sale_check", validate: false
  end
end
