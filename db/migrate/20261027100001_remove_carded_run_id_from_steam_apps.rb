# The contract step: Steam::App ignores `carded_run_id` (strong_migrations
# requires it before the removal), so a process booted before this migration
# is safe too.
class RemoveCardedRunIdFromSteamApps < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :steam_apps, :carded_run_id, :bigint }
  end
end
