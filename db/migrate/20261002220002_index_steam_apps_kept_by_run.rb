# The apps a run kept, in appid order (Steam::App.kept_by), for the steps
# that page over them. Built concurrently so the table stays writable
# (strong_migrations).
class IndexSteamAppsKeptByRun < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :steam_apps, [ :reviewed_run_id, :appid ], where: "review_exclusion IS NULL",
      name: "index_steam_apps_kept_by_run", algorithm: :concurrently
  end
end
