# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_02_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts_players", force: :cascade do |t|
    t.string "steam_id", null: false
    t.string "token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "player", null: false
    t.datetime "banned_at"
    t.index ["steam_id"], name: "index_accounts_players_on_steam_id", unique: true
    t.index ["token"], name: "index_accounts_players_on_token", unique: true
    t.check_constraint "role::text = 'player'::text OR role::text = 'moderator'::text OR role::text = 'administrator'::text", name: "accounts_players_role_check"
  end

  create_table "event_store_events", force: :cascade do |t|
    t.uuid "event_id", null: false
    t.string "event_type", null: false
    t.jsonb "metadata"
    t.jsonb "data", null: false
    t.datetime "created_at", null: false
    t.datetime "valid_at"
    t.index "COALESCE(valid_at, created_at)", name: "index_event_store_events_on_as_of"
    t.index ["created_at"], name: "index_event_store_events_on_created_at"
    t.index ["event_id"], name: "index_event_store_events_on_event_id", unique: true
    t.index ["event_type"], name: "index_event_store_events_on_event_type"
    t.index ["valid_at"], name: "index_event_store_events_on_valid_at"
  end

  create_table "event_store_events_in_streams", force: :cascade do |t|
    t.string "stream", null: false
    t.integer "position"
    t.uuid "event_id", null: false
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_event_store_events_in_streams_on_created_at"
    t.index ["event_id"], name: "index_event_store_events_in_streams_on_event_id"
    t.index ["stream", "event_id"], name: "index_event_store_events_in_streams_on_stream_and_event_id", unique: true
    t.index ["stream", "id"], name: "index_event_store_events_in_streams_on_stream_and_id"
    t.index ["stream", "position"], name: "index_event_store_events_in_streams_on_stream_and_position", unique: true
  end

  create_table "steam_apps", force: :cascade do |t|
    t.bigint "appid", null: false
    t.string "name", null: false
    t.datetime "last_modified"
    t.bigint "price_change_number"
    t.bigint "import_run_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appid"], name: "index_steam_apps_on_appid", unique: true
    t.index ["import_run_id"], name: "index_steam_apps_on_import_run_id"
  end

  create_table "steam_import_runs", force: :cascade do |t|
    t.string "token", null: false
    t.string "status", default: "pending", null: false
    t.string "step"
    t.jsonb "cursor", default: {}, null: false
    t.jsonb "counts", default: {}, null: false
    t.jsonb "error_messages", default: [], null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "(true)", name: "index_steam_import_runs_one_active", unique: true, where: "(((status)::text = 'pending'::text) OR ((status)::text = 'running'::text))"
    t.index ["created_at"], name: "index_steam_import_runs_on_created_at"
    t.index ["token"], name: "index_steam_import_runs_on_token", unique: true
    t.check_constraint "status::text = 'pending'::text OR status::text = 'running'::text OR status::text = 'completed'::text OR status::text = 'failed'::text", name: "steam_import_runs_status_check"
  end

  add_foreign_key "event_store_events_in_streams", "event_store_events", column: "event_id", primary_key: "event_id"
  add_foreign_key "steam_apps", "steam_import_runs", column: "import_run_id"
end
