# The apps a run detailed and did not exclude, in appid order
# (Steam::App.detailed_by), for the genres step that pages over them. Built
# concurrently so the table stays writable (strong_migrations).
class IndexSteamAppsDetailedByRun < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :steam_apps, [ :details_run_id, :appid ], where: "details_exclusion IS NULL",
      name: "index_steam_apps_detailed_by_run", algorithm: :concurrently
  end
end
