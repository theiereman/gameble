class IndexGameFeedReactionsOnFeedEntryId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_reactions, %i[feed_entry_id kind], algorithm: :concurrently
  end
end
