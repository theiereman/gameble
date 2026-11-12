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

ActiveRecord::Schema[8.1].define(version: 2026_11_12_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts_announcement_dismissals", force: :cascade do |t|
    t.bigint "announcement_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.index ["announcement_id", "player_id"], name: "index_accounts_announcement_dismissals_uniqueness", unique: true
    t.index ["player_id"], name: "index_accounts_announcement_dismissals_on_player_id"
  end

  create_table "accounts_announcements", force: :cascade do |t|
    t.string "token", null: false
    t.text "message_fr", null: false
    t.text "message_en", null: false
    t.boolean "shown", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shown"], name: "index_accounts_announcements_one_shown", unique: true, where: "shown"
    t.index ["token"], name: "index_accounts_announcements_on_token", unique: true
    t.check_constraint "char_length(message_fr) >= 1 AND char_length(message_fr) <= 280 AND char_length(message_en) >= 1 AND char_length(message_en) <= 280", name: "accounts_announcements_message_length_check"
  end

  create_table "accounts_data_exports", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.text "file", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_accounts_data_exports_on_player_id", unique: true
  end

  create_table "accounts_identities", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "clerk_user_id"
    t.index ["clerk_user_id"], name: "index_accounts_identities_on_clerk_user_id"
    t.index ["email_hash"], name: "index_accounts_identities_on_email_hash"
    t.index ["player_id"], name: "index_accounts_identities_on_player_id"
    t.index ["provider", "uid"], name: "index_accounts_identities_on_provider_and_uid", unique: true
    t.check_constraint "provider::text ~ '^(steam|apple|discord|google|email)$'::text", name: "accounts_identities_provider_check"
  end

  create_table "accounts_moderation_actions", force: :cascade do |t|
    t.string "kind", null: false
    t.bigint "player_id", null: false
    t.bigint "staff_id", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_accounts_moderation_actions_on_created_at"
    t.index ["player_id", "created_at"], name: "index_accounts_moderation_actions_on_player_id_and_created_at"
    t.index ["staff_id"], name: "index_accounts_moderation_actions_on_staff_id"
    t.check_constraint "kind::text = 'ban'::text OR kind::text = 'unban'::text OR kind::text = 'dismissal'::text OR kind::text = 'erasure'::text", name: "accounts_moderation_actions_kind_values_check"
    t.check_constraint "reason IS NULL OR char_length(reason) <= 500", name: "accounts_moderation_actions_reason_length_check"
    t.check_constraint "reason IS NULL OR kind::text = 'ban'::text", name: "accounts_moderation_actions_reason_kind_check"
  end

  create_table "accounts_players", force: :cascade do |t|
    t.string "steam_id"
    t.string "token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "player", null: false
    t.datetime "banned_at"
    t.string "persona_name"
    t.boolean "reduced_motion"
    t.string "visibility", default: "public", null: false
    t.datetime "last_seen_at"
    t.datetime "deleted_at"
    t.uuid "stream_key", default: -> { "gen_random_uuid()" }, null: false
    t.datetime "last_exported_at"
    t.boolean "welcome_pending", default: false, null: false
    t.boolean "steam_library_sync", default: true, null: false
    t.index ["steam_id"], name: "index_accounts_players_on_steam_id", unique: true
    t.index ["stream_key"], name: "index_accounts_players_on_stream_key", unique: true
    t.index ["token"], name: "index_accounts_players_on_token", unique: true
    t.check_constraint "deleted_at IS NULL OR steam_id IS NULL", name: "accounts_players_deleted_no_steam_id_check"
    t.check_constraint "persona_name IS NULL OR char_length(persona_name::text) <= 512", name: "accounts_players_persona_name_length_check"
    t.check_constraint "role::text = 'player'::text OR role::text = 'moderator'::text OR role::text = 'administrator'::text", name: "accounts_players_role_check"
    t.check_constraint "visibility::text = 'public'::text OR visibility::text = 'friends_only'::text OR visibility::text = 'private'::text", name: "accounts_players_visibility_check"
  end

  create_table "accounts_push_devices", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "platform", null: false
    t.string "token", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_accounts_push_devices_on_player_id"
    t.index ["token"], name: "index_accounts_push_devices_on_token", unique: true
    t.check_constraint "char_length(token::text) <= 4096", name: "accounts_push_devices_token_length_check"
    t.check_constraint "platform::text ~ '^(apple|google)$'::text", name: "accounts_push_devices_platform_check"
  end

  create_table "accounts_release_note_reads", force: :cascade do |t|
    t.bigint "release_note_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.index ["player_id"], name: "index_accounts_release_note_reads_on_player_id"
    t.index ["release_note_id", "player_id"], name: "index_accounts_release_note_reads_uniqueness", unique: true
  end

  create_table "accounts_release_notes", force: :cascade do |t|
    t.string "token", null: false
    t.string "version", null: false
    t.string "state", default: "draft", null: false
    t.string "title_fr", default: "", null: false
    t.string "title_en", default: "", null: false
    t.text "body_fr", default: "", null: false
    t.text "body_en", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_accounts_release_notes_on_token", unique: true
    t.index ["version"], name: "index_accounts_release_notes_on_version", unique: true
    t.check_constraint "char_length(title_fr::text) <= 80 AND char_length(title_en::text) <= 80 AND char_length(body_fr) <= 1500 AND char_length(body_en) <= 1500", name: "accounts_release_notes_length_check"
    t.check_constraint "state::text = 'draft'::text OR state::text = 'ready'::text OR state::text = 'skipped'::text", name: "accounts_release_notes_state_check"
    t.check_constraint "version::text ~ '^v[0-9]+\\.[0-9]+\\.[0-9]+$'::text", name: "accounts_release_notes_version_check"
  end

  create_table "accounts_reports", force: :cascade do |t|
    t.bigint "reporter_id", null: false
    t.bigint "reported_id", null: false
    t.string "reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "handled_at"
    t.index ["reported_id"], name: "index_accounts_reports_on_reported_id"
    t.index ["reporter_id", "created_at"], name: "index_accounts_reports_on_reporter_id_and_created_at"
    t.index ["reporter_id", "reported_id"], name: "index_accounts_reports_on_reporter_id_and_reported_id", unique: true
    t.check_constraint "reason::text = 'inappropriate_name'::text OR reason::text = 'cheating'::text OR reason::text = 'harassment'::text OR reason::text = 'other'::text", name: "accounts_reports_reason_check"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "catalog_card_seasons", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.bigint "season_id", null: false
    t.float "prestige_score", null: false
    t.decimal "rating", precision: 5, scale: 2, null: false
    t.integer "rarity", limit: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "number"
    t.integer "prestige_score_version", limit: 2
    t.integer "review_count"
    t.string "main_theme"
    t.index ["card_id", "season_id"], name: "index_catalog_card_seasons_on_card_id_and_season_id", unique: true
    t.index ["season_id", "number"], name: "index_catalog_card_seasons_on_season_id_and_number", unique: true
    t.index ["season_id"], name: "index_catalog_card_seasons_on_season_id"
    t.check_constraint "number > 0", name: "catalog_card_seasons_number_check"
    t.check_constraint "rarity >= 1 AND rarity <= 5", name: "catalog_card_seasons_rarity_check"
    t.check_constraint "rarity IS NULL OR number IS NOT NULL", name: "catalog_card_seasons_rarity_requires_number_check"
    t.check_constraint "rating >= 0::numeric AND rating <= 100::numeric", name: "catalog_card_seasons_rating_check"
    t.check_constraint "review_count IS NULL OR review_count >= 1", name: "catalog_card_seasons_review_count_check"
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
    t.string "genres", default: [], null: false, array: true
    t.string "tags", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "developers", default: [], null: false, array: true
    t.string "franchises", default: [], null: false, array: true
    t.index ["slug"], name: "index_catalog_cards_on_slug", unique: true
    t.index ["source_key"], name: "index_catalog_cards_on_source_key", unique: true
  end

  create_table "catalog_roadmap_milestones", force: :cascade do |t|
    t.string "token", null: false
    t.string "epic_slug"
    t.string "wording_fr", null: false
    t.string "wording_en", null: false
    t.string "status", default: "to_come", null: false
    t.boolean "shown", default: false, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_catalog_roadmap_milestones_on_token", unique: true
    t.check_constraint "status::text = 'done'::text OR status::text = 'in_progress'::text OR status::text = 'to_come'::text", name: "catalog_roadmap_milestones_status_check"
  end

  create_table "catalog_roadmap_stories", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "milestone_id", null: false
    t.string "wording_fr", null: false
    t.string "wording_en", null: false
    t.string "status", default: "to_come", null: false
    t.boolean "shown", default: true, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["milestone_id"], name: "index_catalog_roadmap_stories_on_milestone_id"
    t.index ["token"], name: "index_catalog_roadmap_stories_on_token", unique: true
    t.check_constraint "status::text = 'done'::text OR status::text = 'in_progress'::text OR status::text = 'to_come'::text", name: "catalog_roadmap_stories_status_check"
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

  create_table "catalog_set_tiers", force: :cascade do |t|
    t.bigint "set_id", null: false
    t.string "tier", null: false
    t.integer "required", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["set_id", "tier"], name: "index_catalog_set_tiers_on_set_id_and_tier", unique: true
    t.check_constraint "required > 0", name: "catalog_set_tiers_required_check"
    t.check_constraint "tier::text = 'bronze'::text OR tier::text = 'silver'::text OR tier::text = 'gold'::text OR tier::text = 'novice'::text OR tier::text = 'apprentice'::text OR tier::text = 'adept'::text OR tier::text = 'expert'::text OR tier::text = 'master'::text OR tier::text = 'complete'::text", name: "catalog_set_tiers_tier_check"
  end

  create_table "catalog_sets", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.string "kind", null: false
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "params", default: {}, null: false
    t.index ["season_id", "kind", "key"], name: "index_catalog_sets_on_season_id_and_kind_and_key", unique: true
    t.check_constraint "kind::text = 'theme'::text OR kind::text = 'franchise'::text OR kind::text = 'studio'::text OR kind::text = 'hall_of_fame'::text OR kind::text = 'ufo'::text", name: "catalog_sets_kind_check"
  end

  create_table "catalog_share_images", force: :cascade do |t|
    t.bigint "card_season_id", null: false
    t.string "locale", null: false
    t.string "token", null: false
    t.string "fingerprint", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id", "locale"], name: "index_catalog_share_images_on_card_season_id_and_locale", unique: true
    t.index ["token"], name: "index_catalog_share_images_on_token", unique: true
    t.check_constraint "locale::text = 'en'::text OR locale::text = 'fr'::text", name: "catalog_share_images_locale_check"
  end

  create_table "catalog_staged_card_seasons", force: :cascade do |t|
    t.string "batch_token", null: false
    t.bigint "card_id", null: false
    t.float "prestige_score", null: false
    t.integer "prestige_score_version", limit: 2
    t.decimal "rating", precision: 5, scale: 2, null: false
    t.integer "review_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_token", "card_id"], name: "index_catalog_staged_card_seasons_on_batch_token_and_card_id", unique: true
    t.index ["card_id"], name: "index_catalog_staged_card_seasons_on_card_id"
    t.check_constraint "rating >= 0::numeric AND rating <= 100::numeric", name: "catalog_staged_card_seasons_rating_check"
    t.check_constraint "review_count IS NULL OR review_count >= 1", name: "catalog_staged_card_seasons_review_count_check"
  end

  create_table "catalog_tag_classifications", force: :cascade do |t|
    t.string "tag_key", null: false
    t.bigint "theme_id"
    t.boolean "not_a_theme", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_key"], name: "index_catalog_tag_classifications_on_tag_key", unique: true
    t.index ["theme_id"], name: "index_catalog_tag_classifications_on_theme_id"
    t.check_constraint "(theme_id IS NULL) = not_a_theme", name: "catalog_tag_classifications_one_state_check"
  end

  create_table "catalog_themes", force: :cascade do |t|
    t.string "token", null: false
    t.string "key", null: false
    t.string "name_en", null: false
    t.string "name_fr", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_catalog_themes_on_key", unique: true
    t.index ["token"], name: "index_catalog_themes_on_token", unique: true
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

  create_table "game_achievement_unlocks", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "achievement", null: false
    t.datetime "unlocked_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "claimed_at"
    t.index ["player_id", "achievement"], name: "index_game_achievement_unlocks_on_player_id_and_achievement", unique: true
  end

  create_table "game_card_back_unlocks", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "back", null: false
    t.datetime "unlocked_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "back"], name: "index_game_card_back_unlocks_on_player_id_and_back", unique: true
  end

  create_table "game_custom_set_games", force: :cascade do |t|
    t.bigint "custom_set_id", null: false
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_game_custom_set_games_on_card_id"
    t.index ["custom_set_id", "card_id"], name: "index_game_custom_set_games_on_custom_set_id_and_card_id", unique: true
  end

  create_table "game_custom_sets", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "token", null: false
    t.string "kind", null: false
    t.string "name"
    t.datetime "synced_at"
    t.datetime "library_private_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "player_id, lower((name)::text)", name: "index_game_custom_sets_on_player_id_and_lower_name", unique: true, where: "((kind)::text = 'custom'::text)"
    t.index ["player_id"], name: "index_game_custom_sets_on_player_id"
    t.index ["player_id"], name: "index_game_custom_sets_one_library_per_player", unique: true, where: "((kind)::text = 'steam_library'::text)"
    t.index ["token"], name: "index_game_custom_sets_on_token", unique: true
    t.check_constraint "kind::text <> 'custom'::text OR name IS NOT NULL AND char_length(name::text) >= 1 AND char_length(name::text) <= 40", name: "game_custom_sets_name_check"
    t.check_constraint "kind::text <> 'custom'::text OR synced_at IS NULL AND library_private_since IS NULL", name: "game_custom_sets_sync_check"
    t.check_constraint "kind::text = 'custom'::text OR kind::text = 'steam_library'::text", name: "game_custom_sets_kind_check"
  end

  create_table "game_daily_bonus_claims", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.date "day", null: false
    t.bigint "pack_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pack_id"], name: "index_game_daily_bonus_claims_on_pack_id"
    t.index ["player_id", "day"], name: "index_game_daily_bonus_claims_on_player_id_and_day", unique: true
  end

  create_table "game_feed_entries", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "pack_id"
    t.bigint "card_season_id"
    t.integer "position"
    t.integer "rarity"
    t.boolean "notable", default: true, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind", default: "pull", null: false
    t.bigint "trade_id"
    t.bigint "partner_id"
    t.bigint "partner_card_season_id"
    t.bigint "set_id"
    t.string "tier"
    t.integer "set_count"
    t.uuid "token", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "listing_id"
    t.index ["kind", "notable", "occurred_at"], name: "index_game_feed_entries_on_kind_and_notable_and_occurred_at"
    t.index ["listing_id"], name: "index_game_feed_entries_one_sale_per_listing", unique: true, where: "((kind)::text = 'sale'::text)"
    t.index ["notable", "occurred_at", "id"], name: "index_game_feed_entries_on_notable_and_occurred_at_and_id"
    t.index ["occurred_at"], name: "index_game_feed_entries_one_verdict_per_week", unique: true, where: "((kind)::text = 'verdict'::text)"
    t.index ["pack_id", "position"], name: "index_game_feed_entries_on_pack_id_and_position", unique: true
    t.index ["partner_id"], name: "index_game_feed_entries_on_partner_id"
    t.index ["player_id", "occurred_at"], name: "index_game_feed_entries_one_set_per_operation", unique: true, where: "((kind)::text = 'set'::text)"
    t.index ["player_id"], name: "index_game_feed_entries_on_player_id"
    t.index ["token"], name: "index_game_feed_entries_on_token", unique: true
    t.index ["trade_id"], name: "index_game_feed_entries_on_trade_id", unique: true, where: "(trade_id IS NOT NULL)"
    t.check_constraint "(kind::text = 'pull'::text OR kind::text = 'discovery'::text) = (pack_id IS NOT NULL AND \"position\" IS NOT NULL)", name: "game_feed_entries_pack_check"
    t.check_constraint "(kind::text = 'sale'::text) = (listing_id IS NOT NULL)", name: "game_feed_entries_sale_check"
    t.check_constraint "(kind::text = 'set'::text) = (set_id IS NOT NULL AND tier IS NOT NULL AND set_count IS NOT NULL) AND (kind::text = 'set'::text OR kind::text = 'verdict'::text) = (card_season_id IS NULL) AND (kind::text = 'set'::text OR kind::text = 'verdict'::text) = (rarity IS NULL)", name: "game_feed_entries_set_check"
    t.check_constraint "(kind::text = 'trade'::text) = (trade_id IS NOT NULL AND partner_id IS NOT NULL AND partner_card_season_id IS NOT NULL)", name: "game_feed_entries_trade_check"
    t.check_constraint "(tier IS NULL OR tier::text = 'bronze'::text OR tier::text = 'silver'::text OR tier::text = 'gold'::text OR tier::text = 'novice'::text OR tier::text = 'apprentice'::text OR tier::text = 'adept'::text OR tier::text = 'expert'::text OR tier::text = 'master'::text OR tier::text = 'complete'::text) AND (set_count IS NULL OR set_count > 0)", name: "game_feed_entries_tier_check"
    t.check_constraint "kind::text = 'pull'::text OR kind::text = 'discovery'::text OR kind::text = 'trade'::text OR kind::text = 'repost'::text OR kind::text = 'set'::text OR kind::text = 'verdict'::text OR kind::text = 'sale'::text", name: "game_feed_entries_kind_check"
    t.check_constraint "rarity >= 1 AND rarity <= 5", name: "game_feed_entries_rarity_check"
  end

  create_table "game_feed_reactions", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "feed_entry_id", null: false
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_entry_id", "kind"], name: "index_game_feed_reactions_on_feed_entry_id_and_kind"
    t.index ["player_id", "feed_entry_id"], name: "index_game_feed_reactions_on_player_id_and_feed_entry_id", unique: true
    t.check_constraint "kind::text = 'thumb'::text OR kind::text = 'heart'::text OR kind::text = 'gg'::text OR kind::text = 'wow'::text OR kind::text = 'middle_finger'::text", name: "game_feed_reactions_kind_check"
  end

  create_table "game_first_discoveries", force: :cascade do |t|
    t.bigint "card_season_id", null: false
    t.bigint "player_id", null: false
    t.bigint "pack_id"
    t.datetime "discovered_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id"], name: "index_game_first_discoveries_on_card_season_id", unique: true
    t.index ["pack_id"], name: "index_game_first_discoveries_on_pack_id"
    t.index ["player_id"], name: "index_game_first_discoveries_on_player_id"
  end

  create_table "game_fortunes", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.date "week_start"
    t.integer "regular_packs", default: 0, null: false
    t.integer "bonus_packs", default: 0, null: false
    t.integer "reward_packs", default: 0, null: false
    t.integer "common_cards", default: 0, null: false
    t.integer "uncommon_cards", default: 0, null: false
    t.integer "rare_cards", default: 0, null: false
    t.integer "epic_cards", default: 0, null: false
    t.integer "legendary_cards", default: 0, null: false
    t.integer "actual_points", default: 0, null: false
    t.float "expected_points", default: 0.0, null: false
    t.float "variance", default: 0.0, null: false
    t.virtual "z_score", type: :float, as: "\nCASE\n    WHEN (variance > (0)::double precision) THEN (((actual_points)::double precision - expected_points) / sqrt(variance))\n    ELSE (0)::double precision\nEND", stored: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "week_start"], name: "index_game_fortunes_on_player_id_and_week_start", unique: true, nulls_not_distinct: true
    t.index ["week_start", "z_score", "player_id"], name: "index_game_fortunes_on_week_start_and_z_score_and_player_id", order: { z_score: :desc }
    t.check_constraint "regular_packs >= 0 AND bonus_packs >= 0 AND reward_packs >= 0", name: "game_fortunes_packs_check"
    t.check_constraint "variance >= 0::double precision", name: "game_fortunes_variance_check"
    t.check_constraint "week_start IS NULL OR EXTRACT(isodow FROM week_start) = 1::numeric", name: "game_fortunes_week_start_monday_check"
  end

  create_table "game_friend_codes", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_game_friend_codes_on_code", unique: true
    t.index ["player_id"], name: "index_game_friend_codes_on_player_id", unique: true
    t.check_constraint "code::text ~ '^[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}$'::text", name: "game_friend_codes_code_check"
  end

  create_table "game_friendships", force: :cascade do |t|
    t.bigint "low_player_id", null: false
    t.bigint "high_player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["high_player_id"], name: "index_game_friendships_on_high_player_id"
    t.index ["low_player_id", "high_player_id"], name: "index_game_friendships_on_low_player_id_and_high_player_id", unique: true
    t.check_constraint "low_player_id < high_player_id", name: "game_friendships_order_check"
  end

  create_table "game_goal_rewards", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.date "week_start", null: false
    t.bigint "pack_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pack_id"], name: "index_game_goal_rewards_on_pack_id"
    t.index ["player_id", "week_start"], name: "index_game_goal_rewards_on_player_id_and_week_start", unique: true
    t.index ["week_start"], name: "index_game_goal_rewards_on_week_start"
  end

  create_table "game_goals", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.integer "position", null: false
    t.string "set_kind"
    t.string "set_key"
    t.bigint "custom_set_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_set_id"], name: "index_game_goals_on_custom_set_id", unique: true, where: "(custom_set_id IS NOT NULL)"
    t.index ["player_id", "position"], name: "index_game_goals_on_player_id_and_position", unique: true
    t.index ["player_id", "set_kind", "set_key"], name: "index_game_goals_on_player_id_and_game_set", unique: true, where: "(set_kind IS NOT NULL)"
    t.check_constraint "(custom_set_id IS NULL) = (set_kind IS NOT NULL) AND (set_kind IS NULL) = (set_key IS NULL)", name: "game_goals_target_check"
    t.check_constraint "\"position\" >= 1 AND \"position\" <= 5", name: "game_goals_position_check"
    t.check_constraint "set_kind IS NULL OR set_kind::text = 'theme'::text OR set_kind::text = 'franchise'::text OR set_kind::text = 'studio'::text OR set_kind::text = 'hall_of_fame'::text OR set_kind::text = 'ufo'::text", name: "game_goals_set_kind_check"
  end

  create_table "game_holdings", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "card_season_id", null: false
    t.integer "quantity", default: 0, null: false
    t.integer "reserved", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_gained_at"
    t.index ["card_season_id"], name: "index_game_holdings_on_card_season_id"
    t.index ["player_id", "card_season_id"], name: "index_game_holdings_on_player_id_and_card_season_id", unique: true
    t.check_constraint "quantity >= reserved AND reserved >= 0", name: "game_holdings_quantity_check"
  end

  create_table "game_invitations", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "sender_id", null: false
    t.bigint "recipient_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_id"], name: "index_game_invitations_on_recipient_id"
    t.index ["sender_id", "recipient_id"], name: "index_game_invitations_one_pending_per_pair", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["sender_id"], name: "index_game_invitations_on_sender_id"
    t.index ["token"], name: "index_game_invitations_on_token", unique: true
    t.check_constraint "sender_id <> recipient_id", name: "game_invitations_distinct_check"
    t.check_constraint "status::text = 'pending'::text OR status::text = 'accepted'::text OR status::text = 'ignored'::text", name: "game_invitations_status_check"
  end

  create_table "game_market_alt_signals", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "signal", null: false
    t.bigint "other_account_id"
    t.jsonb "facts", default: {}, null: false
    t.datetime "refreshed_at", null: false
    t.index ["account_id"], name: "index_game_market_alt_signals_on_account_id"
    t.index ["other_account_id"], name: "index_game_market_alt_signals_on_other_account_id"
  end

  create_table "game_market_archive_deposits", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "card_season_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id"], name: "index_game_market_archive_deposits_on_card_season_id"
    t.index ["player_id", "card_season_id"], name: "index_game_market_archive_deposits_uniqueness", unique: true
    t.check_constraint "quantity > 0", name: "game_market_archive_deposits_quantity_check"
  end

  create_table "game_market_archive_stocks", force: :cascade do |t|
    t.bigint "card_season_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id"], name: "index_game_market_archive_stocks_uniqueness", unique: true
    t.check_constraint "quantity > 0", name: "game_market_archive_stocks_quantity_check"
  end

  create_table "game_market_bids", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.bigint "player_id", null: false
    t.bigint "maximum", null: false
    t.bigint "price_after", null: false
    t.string "outcome", null: false
    t.datetime "extended_until"
    t.datetime "created_at", null: false
    t.index ["listing_id", "id"], name: "index_game_market_bids_on_listing_and_id"
    t.index ["player_id", "listing_id"], name: "index_game_market_bids_on_player_and_listing"
    t.check_constraint "maximum > 0", name: "game_market_bids_maximum_check"
    t.check_constraint "outcome::text ~ '^(leading|outbid|beaten|raise|won|lost|voided)$'::text", name: "game_market_bids_outcome_check"
    t.check_constraint "price_after > 0", name: "game_market_bids_price_after_check"
  end

  create_table "game_market_chart_publications", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "published_at"
    t.datetime "unpublished_at"
    t.bigint "changed_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_game_market_chart_publications_on_changed_by_id"
    t.index ["kind"], name: "index_game_market_chart_publications_on_kind", unique: true
    t.check_constraint "kind::text ~ '^(reactor|rarity_prices|edition_sales)$'::text", name: "game_market_chart_publications_kind_check"
  end

  create_table "game_market_daily_snapshots", force: :cascade do |t|
    t.date "day", null: false
    t.bigint "created", null: false
    t.bigint "destroyed_total", null: false
    t.bigint "forfeited", null: false
    t.bigint "circulation", null: false
    t.bigint "picoins_per_active_player"
    t.bigint "median_daily_earnings"
    t.bigint "average_price_common"
    t.bigint "average_price_uncommon"
    t.bigint "average_price_rare"
    t.bigint "average_price_epic"
    t.bigint "average_price_legendary"
    t.integer "top_share_basis_points"
    t.boolean "reconciliation_balanced", null: false
    t.integer "wallet_differences", default: 0, null: false
    t.bigint "circulation_difference", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["day"], name: "index_game_market_daily_snapshots_on_day", unique: true
    t.check_constraint "created >= 0 AND destroyed_total >= 0 AND forfeited >= 0 AND forfeited <= destroyed_total", name: "game_market_daily_snapshots_flows_check"
    t.check_constraint "top_share_basis_points IS NULL OR top_share_basis_points >= 0 AND top_share_basis_points <= 10000", name: "game_market_daily_snapshots_top_share_check"
  end

  create_table "game_market_edition_prices", force: :cascade do |t|
    t.bigint "card_season_id", null: false
    t.bigint "average"
    t.integer "sales_used", default: 0, null: false
    t.datetime "refreshed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id"], name: "index_game_market_edition_prices_on_card_season_id", unique: true
    t.check_constraint "(average IS NULL) = (sales_used = 0)", name: "game_market_edition_prices_average_sales_check"
    t.check_constraint "average IS NULL OR average >= 0", name: "game_market_edition_prices_average_check"
    t.check_constraint "sales_used >= 0", name: "game_market_edition_prices_sales_used_check"
  end

  create_table "game_market_ledger_entries", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "kind", null: false
    t.bigint "available_delta", default: 0, null: false
    t.bigint "committed_delta", default: 0, null: false
    t.bigint "listing_id"
    t.bigint "settings_id", null: false
    t.datetime "created_at", null: false
    t.index ["listing_id", "player_id", "kind"], name: "index_game_market_ledger_entries_one_settlement", unique: true, where: "(((kind)::text = 'stamp'::text) OR ((kind)::text = 'purchase'::text) OR ((kind)::text = 'sale'::text) OR ((kind)::text = 'commission'::text))"
    t.index ["player_id"], name: "index_game_market_ledger_entries_on_player_id"
    t.index ["settings_id"], name: "index_game_market_ledger_entries_on_settings_id"
    t.check_constraint "kind::text ~ '^(mint|stamp|hold|release|purchase|sale|commission|forfeit)$'::text", name: "game_market_ledger_entries_kind_check"
  end

  create_table "game_market_listings", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "seller_id", null: false
    t.bigint "card_season_id", null: false
    t.bigint "settings_id", null: false
    t.bigint "starting_price", null: false
    t.integer "duration_hours", null: false
    t.datetime "ends_at", null: false
    t.bigint "current_price", null: false
    t.bigint "leader_id"
    t.bigint "leader_maximum"
    t.datetime "sold_at"
    t.bigint "final_price"
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "average_after_sale"
    t.index ["card_season_id", "sold_at"], name: "index_game_market_listings_sold_card_season", where: "((status)::text = 'sold'::text)"
    t.index ["current_price", "id"], name: "index_game_market_listings_open_current_price", where: "((status)::text = 'open'::text)"
    t.index ["ends_at"], name: "index_game_market_listings_open_ends_at", where: "((status)::text = 'open'::text)"
    t.index ["seller_id", "status"], name: "index_game_market_listings_on_seller_id_and_status"
    t.index ["token"], name: "index_game_market_listings_on_token", unique: true
    t.check_constraint "(leader_id IS NULL) = (leader_maximum IS NULL)", name: "game_market_listings_leader_check"
    t.check_constraint "(sold_at IS NULL) = (final_price IS NULL)", name: "game_market_listings_sold_check"
    t.check_constraint "current_price >= starting_price", name: "game_market_listings_current_price_check"
    t.check_constraint "duration_hours > 0", name: "game_market_listings_duration_check"
    t.check_constraint "starting_price > 0", name: "game_market_listings_starting_price_check"
    t.check_constraint "status::text ~ '^(open|sold|unsold|cancelled|withdrawn)$'::text", name: "game_market_listings_status_check"
  end

  create_table "game_market_notices", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "listing_id", null: false
    t.string "kind", null: false
    t.bigint "other_player_id"
    t.bigint "amount"
    t.datetime "noticed_at", null: false
    t.index ["player_id", "listing_id"], name: "index_game_market_notices_on_player_and_listing", unique: true
    t.check_constraint "amount IS NULL OR amount >= 0", name: "game_market_notices_amount_check"
    t.check_constraint "kind::text ~ '^(outbid|won|sold|unsold|lead_voided|withdrawn)$'::text", name: "game_market_notices_kind_check"
  end

  create_table "game_market_settings", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "entrustment_common", null: false
    t.bigint "entrustment_uncommon", null: false
    t.bigint "entrustment_rare", null: false
    t.bigint "entrustment_epic", null: false
    t.bigint "entrustment_legendary", null: false
    t.bigint "stamp_common", null: false
    t.bigint "stamp_uncommon", null: false
    t.bigint "stamp_rare", null: false
    t.bigint "stamp_epic", null: false
    t.bigint "stamp_legendary", null: false
    t.bigint "minimum_price_common", null: false
    t.bigint "minimum_price_uncommon", null: false
    t.bigint "minimum_price_rare", null: false
    t.bigint "minimum_price_epic", null: false
    t.bigint "minimum_price_legendary", null: false
    t.integer "commission_basis_points", null: false
    t.bigint "daily_cap", null: false
    t.integer "duration_short_hours", null: false
    t.integer "duration_medium_hours", null: false
    t.integer "duration_long_hours", null: false
    t.integer "preselected_duration_hours", null: false
    t.integer "increment_basis_points", null: false
    t.integer "soft_close_seconds", null: false
    t.integer "average_sale_count", null: false
    t.integer "average_window_days", null: false
    t.integer "feed_threshold_multiple", null: false
    t.integer "unusual_maximum_multiple", null: false
    t.integer "alert_destroyed_share_basis_points"
    t.bigint "alert_picoins_per_player"
    t.integer "alert_top_share_basis_points"
    t.decimal "income_days_target_common", precision: 10, scale: 3
    t.decimal "income_days_target_uncommon", precision: 10, scale: 3
    t.decimal "income_days_target_rare", precision: 10, scale: 3
    t.decimal "income_days_target_epic", precision: 10, scale: 3
    t.decimal "income_days_target_legendary", precision: 10, scale: 3
    t.boolean "open", default: false, null: false
    t.datetime "terms_confirmed_at"
    t.datetime "odds_confirmed_at"
    t.datetime "first_opened_at"
    t.bigint "author_id"
    t.bigint "replaces_id"
    t.datetime "created_at", null: false
    t.index ["author_id"], name: "index_game_market_settings_on_author_id"
    t.index ["replaces_id"], name: "index_game_market_settings_on_replaces_id", unique: true
    t.index ["token"], name: "index_game_market_settings_on_token", unique: true
    t.check_constraint "commission_basis_points >= 0 AND commission_basis_points <= 2500", name: "game_market_settings_commission_check"
    t.check_constraint "daily_cap > 0 AND increment_basis_points > 0 AND soft_close_seconds > 0", name: "game_market_settings_positive_check"
    t.check_constraint "preselected_duration_hours = duration_short_hours OR preselected_duration_hours = duration_medium_hours OR preselected_duration_hours = duration_long_hours", name: "game_market_settings_preselected_check"
  end

  create_table "game_market_wallets", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "available", default: 0, null: false
    t.bigint "committed", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_game_market_wallets_on_player_id", unique: true
    t.check_constraint "available >= 0 AND committed >= 0", name: "game_market_wallets_balance_check"
  end

  create_table "game_packs", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "token", null: false
    t.string "kind", null: false
    t.bigint "season_id", null: false
    t.bigint "card_season_ids", null: false, array: true
    t.datetime "available_at", null: false
    t.datetime "opened_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "idempotency_key"
    t.string "card_back"
    t.integer "card_back_season"
    t.string "reveal_mode"
    t.integer "opened_local_hour", limit: 2
    t.index ["opened_at"], name: "index_game_packs_on_opened_at", where: "(opened_at IS NOT NULL)"
    t.index ["player_id", "available_at", "id"], name: "index_game_packs_unopened", where: "(opened_at IS NULL)"
    t.index ["player_id", "idempotency_key"], name: "index_game_packs_on_player_id_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["player_id", "season_id", "opened_at"], name: "index_game_packs_opened", order: { opened_at: :desc }, where: "(opened_at IS NOT NULL)"
    t.index ["player_id"], name: "index_game_packs_on_player_id"
    t.index ["season_id"], name: "index_game_packs_on_season_id"
    t.index ["token"], name: "index_game_packs_on_token", unique: true
    t.check_constraint "array_ndims(card_season_ids) = 1 AND cardinality(card_season_ids) >= 1 AND array_position(card_season_ids, NULL::bigint) IS NULL AND (kind::text <> 'regular'::text OR cardinality(card_season_ids) = 5) AND (kind::text <> 'bonus'::text OR cardinality(card_season_ids) = 3)", name: "game_packs_card_season_ids_check"
    t.check_constraint "kind::text = 'regular'::text OR kind::text = 'bonus'::text OR kind::text = 'reward'::text", name: "game_packs_kind_check"
    t.check_constraint "reveal_mode IS NULL OR reveal_mode::text = 'all'::text OR reveal_mode::text = 'one_by_one'::text", name: "game_packs_reveal_mode_values_check"
  end

  create_table "game_player_states", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "collection_seen_up_to"
    t.string "last_activity"
    t.datetime "last_activity_at"
    t.string "active_card_back"
    t.integer "allocation_received_season"
    t.integer "allocation_seen_season"
    t.string "active_title_kind"
    t.string "active_title_key"
    t.string "active_title_rank"
    t.integer "active_card_back_season"
    t.string "active_avatar"
    t.index ["player_id"], name: "index_game_player_states_on_player_id", unique: true
    t.check_constraint "(active_title_kind IS NULL) = (active_title_key IS NULL) AND (active_title_key IS NULL) = (active_title_rank IS NULL)", name: "game_player_states_active_title_whole_check"
  end

  create_table "game_reaction_notices", force: :cascade do |t|
    t.bigint "feed_entry_id", null: false
    t.bigint "reactor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_entry_id", "reactor_id"], name: "index_game_reaction_notices_on_feed_entry_id_and_reactor_id", unique: true
    t.index ["reactor_id"], name: "index_game_reaction_notices_on_reactor_id"
  end

  create_table "game_set_tiers", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "set_id", null: false
    t.string "tier", null: false
    t.string "reached_by", null: false
    t.bigint "pack_id"
    t.datetime "reached_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "held"
    t.index ["pack_id"], name: "index_game_set_tiers_on_pack_id"
    t.index ["player_id", "set_id", "tier"], name: "index_game_set_tiers_on_player_id_and_set_id_and_tier", unique: true
    t.check_constraint "(reached_by::text = 'pack'::text) = (pack_id IS NOT NULL)", name: "game_set_tiers_pack_check"
    t.check_constraint "reached_by::text = 'pack'::text OR reached_by::text = 'trade'::text OR reached_by::text = 'allocation'::text", name: "game_set_tiers_reached_by_values_check"
    t.check_constraint "tier::text = 'bronze'::text OR tier::text = 'silver'::text OR tier::text = 'gold'::text OR tier::text = 'novice'::text OR tier::text = 'apprentice'::text OR tier::text = 'adept'::text OR tier::text = 'expert'::text OR tier::text = 'master'::text OR tier::text = 'complete'::text", name: "game_set_tiers_tier_check"
  end

  create_table "game_showcase_entries", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "card_season_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id"], name: "index_game_showcase_entries_on_card_season_id"
    t.index ["player_id", "card_season_id"], name: "index_game_showcase_entries_on_player_id_and_card_season_id", unique: true
    t.check_constraint "\"position\" >= 0", name: "game_showcase_entries_position_check"
  end

  create_table "game_trade_items", force: :cascade do |t|
    t.bigint "trade_id", null: false
    t.string "side", null: false
    t.bigint "card_season_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_season_id"], name: "index_game_trade_items_on_card_season_id"
    t.index ["trade_id", "side", "card_season_id"], name: "index_game_trade_items_on_trade_id_and_side_and_card_season_id", unique: true
    t.check_constraint "quantity > 0", name: "game_trade_items_quantity_check"
    t.check_constraint "side::text = 'offer'::text OR side::text = 'request'::text", name: "game_trade_items_side_check"
  end

  create_table "game_trade_views", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "trade_id", null: false
    t.datetime "seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "trade_id"], name: "index_game_trade_views_on_player_id_and_trade_id", unique: true
  end

  create_table "game_trades", force: :cascade do |t|
    t.bigint "low_player_id", null: false
    t.bigint "high_player_id", null: false
    t.bigint "proposer_id", null: false
    t.bigint "recipient_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "proposed_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "token", null: false
    t.index ["proposer_id", "status"], name: "index_game_trades_on_proposer_id_and_status"
    t.index ["recipient_id", "status"], name: "index_game_trades_on_recipient_id_and_status"
    t.index ["token"], name: "index_game_trades_on_token", unique: true
    t.check_constraint "low_player_id < high_player_id", name: "game_trades_order_check"
    t.check_constraint "proposer_id = low_player_id AND recipient_id = high_player_id OR proposer_id = high_player_id AND recipient_id = low_player_id", name: "game_trades_parties_check"
    t.check_constraint "status::text = 'open'::text OR status::text = 'cancelled'::text OR status::text = 'declined'::text OR status::text = 'accepted'::text OR status::text = 'expired'::text", name: "game_trades_status_check"
  end

  create_table "game_weekly_contributions", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.date "week_start", null: false
    t.integer "openings", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "trades", default: 0, null: false
    t.index ["player_id", "week_start"], name: "index_game_weekly_contributions_on_player_id_and_week_start", unique: true
    t.index ["week_start"], name: "index_game_weekly_contributions_on_week_start"
    t.check_constraint "openings >= 0", name: "game_weekly_contributions_openings_check"
    t.check_constraint "trades >= 0", name: "game_weekly_contributions_trades_check"
  end

  create_table "game_weekly_goals", force: :cascade do |t|
    t.date "week_start", null: false
    t.integer "target", null: false
    t.integer "total", default: 0, null: false
    t.datetime "summed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["week_start"], name: "index_game_weekly_goals_on_week_start", unique: true
    t.check_constraint "target > 0 AND total >= 0", name: "game_weekly_goals_figures_check"
  end

  create_table "steam_apps", force: :cascade do |t|
    t.bigint "appid", null: false
    t.string "name", null: false
    t.datetime "last_modified"
    t.bigint "price_change_number"
    t.bigint "import_run_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "review_count"
    t.integer "review_percent_positive"
    t.jsonb "reviews"
    t.bigint "reviewed_run_id"
    t.string "review_exclusion"
    t.string "name_en"
    t.string "name_fr"
    t.text "short_description_en"
    t.text "short_description_fr"
    t.string "publishers", array: true
    t.date "release_on"
    t.integer "tag_ids", array: true
    t.string "store_url_path"
    t.string "image_url"
    t.jsonb "details"
    t.bigint "details_run_id"
    t.string "details_exclusion"
    t.index ["appid"], name: "index_steam_apps_on_appid", unique: true
    t.index ["details_run_id", "appid"], name: "index_steam_apps_detailed_by_run", where: "(details_exclusion IS NULL)"
    t.index ["import_run_id"], name: "index_steam_apps_on_import_run_id"
    t.index ["reviewed_run_id", "appid"], name: "index_steam_apps_kept_by_run", where: "(review_exclusion IS NULL)"
    t.check_constraint "details_exclusion IS NULL OR details_exclusion::text = 'unavailable'::text OR details_exclusion::text = 'not_a_game'::text OR details_exclusion::text = 'no_title'::text OR details_exclusion::text = 'no_vertical_image'::text OR details_exclusion::text = 'no_release_date'::text", name: "steam_apps_details_exclusion_check"
    t.check_constraint "review_exclusion IS NULL OR review_exclusion::text = 'too_few_reviews'::text OR review_exclusion::text = 'unavailable'::text OR review_exclusion::text = 'malformed_reviews'::text", name: "steam_apps_review_exclusion_check"
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
    t.index "(true)", name: "index_steam_import_runs_one_ready", unique: true, where: "((status)::text = 'ready'::text)"
    t.index ["created_at"], name: "index_steam_import_runs_on_created_at"
    t.index ["token"], name: "index_steam_import_runs_on_token", unique: true
    t.check_constraint "status::text = 'pending'::text OR status::text = 'running'::text OR status::text = 'completed'::text OR status::text = 'failed'::text OR status::text = 'abandoned'::text OR status::text = 'ready'::text OR status::text = 'promoted'::text", name: "steam_import_runs_status_check"
  end

  create_table "steam_tags", force: :cascade do |t|
    t.bigint "tagid", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tagid"], name: "index_steam_tags_on_tagid", unique: true
  end

  add_foreign_key "accounts_announcement_dismissals", "accounts_announcements", column: "announcement_id", on_delete: :cascade
  add_foreign_key "accounts_announcement_dismissals", "accounts_players", column: "player_id"
  add_foreign_key "accounts_data_exports", "accounts_players", column: "player_id"
  add_foreign_key "accounts_identities", "accounts_players", column: "player_id"
  add_foreign_key "accounts_moderation_actions", "accounts_players", column: "player_id"
  add_foreign_key "accounts_moderation_actions", "accounts_players", column: "staff_id"
  add_foreign_key "accounts_push_devices", "accounts_players", column: "player_id"
  add_foreign_key "accounts_release_note_reads", "accounts_players", column: "player_id"
  add_foreign_key "accounts_release_note_reads", "accounts_release_notes", column: "release_note_id", on_delete: :cascade
  add_foreign_key "accounts_reports", "accounts_players", column: "reported_id"
  add_foreign_key "accounts_reports", "accounts_players", column: "reporter_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "catalog_card_seasons", "catalog_cards", column: "card_id"
  add_foreign_key "catalog_card_seasons", "catalog_seasons", column: "season_id"
  add_foreign_key "catalog_card_texts", "catalog_cards", column: "card_id"
  add_foreign_key "catalog_roadmap_stories", "catalog_roadmap_milestones", column: "milestone_id"
  add_foreign_key "catalog_set_memberships", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "catalog_set_memberships", "catalog_sets", column: "set_id"
  add_foreign_key "catalog_set_tiers", "catalog_sets", column: "set_id"
  add_foreign_key "catalog_sets", "catalog_seasons", column: "season_id"
  add_foreign_key "catalog_share_images", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "catalog_staged_card_seasons", "catalog_cards", column: "card_id"
  add_foreign_key "catalog_tag_classifications", "catalog_themes", column: "theme_id"
  add_foreign_key "event_store_events_in_streams", "event_store_events", column: "event_id", primary_key: "event_id"
  add_foreign_key "game_achievement_unlocks", "accounts_players", column: "player_id"
  add_foreign_key "game_custom_set_games", "catalog_cards", column: "card_id"
  add_foreign_key "game_custom_set_games", "game_custom_sets", column: "custom_set_id", on_delete: :cascade
  add_foreign_key "game_custom_sets", "accounts_players", column: "player_id"
  add_foreign_key "game_daily_bonus_claims", "accounts_players", column: "player_id"
  add_foreign_key "game_daily_bonus_claims", "game_packs", column: "pack_id"
  add_foreign_key "game_feed_entries", "accounts_players", column: "partner_id"
  add_foreign_key "game_feed_entries", "accounts_players", column: "player_id"
  add_foreign_key "game_feed_entries", "catalog_card_seasons", column: "partner_card_season_id"
  add_foreign_key "game_feed_entries", "game_packs", column: "pack_id"
  add_foreign_key "game_feed_entries", "game_trades", column: "trade_id"
  add_foreign_key "game_feed_reactions", "accounts_players", column: "player_id"
  add_foreign_key "game_feed_reactions", "game_feed_entries", column: "feed_entry_id", on_delete: :cascade
  add_foreign_key "game_first_discoveries", "accounts_players", column: "player_id"
  add_foreign_key "game_first_discoveries", "game_packs", column: "pack_id"
  add_foreign_key "game_fortunes", "accounts_players", column: "player_id"
  add_foreign_key "game_friend_codes", "accounts_players", column: "player_id"
  add_foreign_key "game_friendships", "accounts_players", column: "high_player_id"
  add_foreign_key "game_friendships", "accounts_players", column: "low_player_id"
  add_foreign_key "game_goal_rewards", "accounts_players", column: "player_id"
  add_foreign_key "game_goal_rewards", "game_packs", column: "pack_id"
  add_foreign_key "game_goals", "accounts_players", column: "player_id"
  add_foreign_key "game_goals", "game_custom_sets", column: "custom_set_id", on_delete: :cascade
  add_foreign_key "game_holdings", "accounts_players", column: "player_id"
  add_foreign_key "game_holdings", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "game_invitations", "accounts_players", column: "recipient_id"
  add_foreign_key "game_invitations", "accounts_players", column: "sender_id"
  add_foreign_key "game_market_alt_signals", "accounts_players", column: "account_id"
  add_foreign_key "game_market_alt_signals", "accounts_players", column: "other_account_id"
  add_foreign_key "game_market_archive_deposits", "accounts_players", column: "player_id"
  add_foreign_key "game_market_archive_deposits", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "game_market_archive_stocks", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "game_market_bids", "accounts_players", column: "player_id"
  add_foreign_key "game_market_bids", "game_market_listings", column: "listing_id"
  add_foreign_key "game_market_chart_publications", "accounts_players", column: "changed_by_id"
  add_foreign_key "game_market_edition_prices", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "game_market_ledger_entries", "accounts_players", column: "player_id"
  add_foreign_key "game_market_ledger_entries", "game_market_listings", column: "listing_id"
  add_foreign_key "game_market_ledger_entries", "game_market_settings", column: "settings_id"
  add_foreign_key "game_market_listings", "accounts_players", column: "leader_id"
  add_foreign_key "game_market_listings", "accounts_players", column: "seller_id"
  add_foreign_key "game_market_listings", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "game_market_listings", "game_market_settings", column: "settings_id"
  add_foreign_key "game_market_notices", "accounts_players", column: "other_player_id"
  add_foreign_key "game_market_notices", "accounts_players", column: "player_id"
  add_foreign_key "game_market_notices", "game_market_listings", column: "listing_id"
  add_foreign_key "game_market_settings", "accounts_players", column: "author_id"
  add_foreign_key "game_market_settings", "game_market_settings", column: "replaces_id"
  add_foreign_key "game_market_wallets", "accounts_players", column: "player_id"
  add_foreign_key "game_packs", "accounts_players", column: "player_id"
  add_foreign_key "game_packs", "catalog_seasons", column: "season_id"
  add_foreign_key "game_player_states", "accounts_players", column: "player_id"
  add_foreign_key "game_reaction_notices", "accounts_players", column: "reactor_id"
  add_foreign_key "game_reaction_notices", "game_feed_entries", column: "feed_entry_id", on_delete: :cascade
  add_foreign_key "game_set_tiers", "accounts_players", column: "player_id"
  add_foreign_key "game_set_tiers", "game_packs", column: "pack_id", on_delete: :cascade
  add_foreign_key "game_showcase_entries", "accounts_players", column: "player_id"
  add_foreign_key "game_showcase_entries", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "game_trade_items", "catalog_card_seasons", column: "card_season_id"
  add_foreign_key "game_trade_items", "game_trades", column: "trade_id"
  add_foreign_key "game_trade_views", "accounts_players", column: "player_id"
  add_foreign_key "game_trade_views", "game_trades", column: "trade_id", on_delete: :cascade
  add_foreign_key "game_trades", "accounts_players", column: "high_player_id"
  add_foreign_key "game_trades", "accounts_players", column: "low_player_id"
  add_foreign_key "game_trades", "accounts_players", column: "proposer_id"
  add_foreign_key "game_trades", "accounts_players", column: "recipient_id"
  add_foreign_key "game_weekly_contributions", "accounts_players", column: "player_id"
  add_foreign_key "steam_apps", "steam_import_runs", column: "details_run_id"
  add_foreign_key "steam_apps", "steam_import_runs", column: "import_run_id"
  add_foreign_key "steam_apps", "steam_import_runs", column: "reviewed_run_id"
end
