# The apps whose card a run wrote (Steam::App.carded_by), for the keep list
# of the end of a cards pass and the clearing of a rescore. Built
# concurrently so the table stays writable (strong_migrations).
class IndexSteamAppsCardedByRun < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :steam_apps, [ :carded_run_id, :appid ], name: "index_steam_apps_carded_by_run", algorithm: :concurrently
  end
end
