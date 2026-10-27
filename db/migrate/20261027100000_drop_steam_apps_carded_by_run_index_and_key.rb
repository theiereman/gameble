# The expand step for dropping `steam_apps.carded_run_id`, which nothing reads
# or writes any more: its index and foreign key go first, the column in the
# next migration once Steam::App ignores it.
class DropSteamAppsCardedByRunIndexAndKey < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :steam_apps, [ :carded_run_id, :appid ], name: "index_steam_apps_carded_by_run", algorithm: :concurrently
    remove_foreign_key :steam_apps, :steam_import_runs, column: :carded_run_id
  end
end
