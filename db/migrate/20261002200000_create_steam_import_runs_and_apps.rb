# The Steam import. An import run records its status, its
# current step, the cursor it resumes from, its counts and its errors. The
# database allows one active (pending or running) run at a time.
#
# steam_apps holds the raw app list from IStoreService/GetAppList, games only,
# one row per Steam appid; a page is upserted on appid, so a page fetched twice
# writes nothing twice.
class CreateSteamImportRunsAndApps < ActiveRecord::Migration[8.1]
  def change
    create_table :steam_import_runs do |t|
      t.string :token, null: false
      t.string :status, null: false, default: "pending"
      t.string :step
      t.jsonb :cursor, null: false, default: {}
      t.jsonb :counts, null: false, default: {}
      t.jsonb :error_messages, null: false, default: []
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps

      t.check_constraint "status = 'pending' OR status = 'running' OR status = 'completed' OR status = 'failed'", name: "steam_import_runs_status_check"
      t.index :token, unique: true
      t.index :created_at
      # One active run at a time: every pending or running row indexes the
      # same constant, so a second one is refused.
      t.index "(true)", unique: true, where: "status = 'pending' OR status = 'running'", name: "index_steam_import_runs_one_active"
    end

    create_table :steam_apps do |t|
      t.bigint :appid, null: false
      t.string :name, null: false
      t.datetime :last_modified
      t.bigint :price_change_number
      t.references :import_run, null: false, foreign_key: { to_table: :steam_import_runs }
      t.timestamps

      t.index :appid, unique: true
    end
  end
end
