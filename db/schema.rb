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

ActiveRecord::Schema[8.1].define(version: 2026_10_02_210000) do
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

  create_table "catalog_card_seasons", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.bigint "season_id", null: false
    t.float "prestige_score", null: false
    t.decimal "rating", precision: 5, scale: 2, null: false
    t.integer "rarity", limit: 2
    t.integer "dust_tier", limit: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "season_id"], name: "index_catalog_card_seasons_on_card_id_and_season_id", unique: true
    t.index ["season_id"], name: "index_catalog_card_seasons_on_season_id"
    t.check_constraint "dust_tier >= 0 AND dust_tier <= 4", name: "catalog_card_seasons_dust_tier_check"
    t.check_constraint "rarity >= 1 AND rarity <= 5", name: "catalog_card_seasons_rarity_check"
    t.check_constraint "rating >= 0::numeric AND rating <= 100::numeric", name: "catalog_card_seasons_rating_check"
  end

  create_table "catalog_card_texts", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.string "locale", null: false
    t.string "title", null: false
    t.text "short_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "locale"], name: "index_catalog_card_texts_on_card_id_and_locale", unique: true
    t.check_constraint "locale::text = 'en'::text OR locale::text = 'fr'::text", name: "catalog_card_texts_locale_check"
  end

  create_table "catalog_cards", force: :cascade do |t|
    t.string "source_key", null: false
    t.string "slug", null: false
    t.date "release_date", null: false
    t.string "image_url", null: false
    t.string "store_url", null: false
    t.string "publisher"
    t.string "credit"
    t.string "genres", default: [], null: false, array: true
    t.string "tags", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_catalog_cards_on_slug", unique: true
    t.index ["source_key"], name: "index_catalog_cards_on_source_key", unique: true
  end

  create_table "catalog_seasons", force: :cascade do |t|
    t.integer "number", null: false
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "(true)", name: "index_catalog_seasons_one_draft", unique: true, where: "((status)::text = 'draft'::text)"
    t.index ["number"], name: "index_catalog_seasons_on_number", unique: true
    t.check_constraint "status::text = 'draft'::text OR status::text = 'published'::text", name: "catalog_seasons_status_check"
  end

  create_table "catalog_set_memberships", force: :cascade do |t|
    t.bigint "set_id", null: false
    t.bigint "card_season_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id"], name: "index_catalog_set_memberships_on_card_season_id"
    t.index ["set_id", "card_season_id"], name: "index_catalog_set_memberships_on_set_id_and_card_season_id", unique: true
  end

  create_table "catalog_sets", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.string "kind", null: false
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "kind", "key"], name: "index_catalog_sets_on_season_id_and_kind_and_key", unique: true
    t.check_constraint "kind::text = 'publisher'::text OR kind::text = 'tome'::text OR kind::text = 'best_of_year'::text", name: "catalog_sets_kind_check"
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

  add_foreign_key "catalog_card_seasons", "catalog_cards", column: "card_id"
  add_foreign_key "catalog_card_seasons", "catalog_seasons", column: "season_id"
  add_foreign_key "catalog_card_texts", "catalog_cards", column: "card_id"
  add_foreign_key "catalog_set_memberships", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "catalog_set_memberships", "catalog_sets", column: "set_id"
  add_foreign_key "catalog_sets", "catalog_seasons", column: "season_id"
  add_foreign_key "event_store_events_in_streams", "event_store_events", column: "event_id", primary_key: "event_id"
  add_foreign_key "steam_apps", "steam_import_runs", column: "import_run_id"
end
