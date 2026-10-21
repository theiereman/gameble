class IndexSteamImportRunsOneReady < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :steam_import_runs, "(true)", unique: true, where: "status = 'ready'",
      name: "index_steam_import_runs_one_ready", algorithm: :concurrently
  end
end
