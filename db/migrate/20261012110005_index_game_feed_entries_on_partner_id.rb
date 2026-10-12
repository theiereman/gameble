class IndexGameFeedEntriesOnPartnerId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_feed_entries, :partner_id, algorithm: :concurrently
  end
end
