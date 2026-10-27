# The store details of the Steam import. The
# details step stores, for each game kept by a run, its English and French
# names and short descriptions, publishers, release date, tags, store path and
# library image, the raw GetItems item, the run that detailed it and that
# run's verdict (NULL when the game can become a card). The genres step adds
# the genres, the credit (legal notice), the raw appdetails data, its run and
# its verdict.
#
# Foreign keys and check constraints are added without validation and
# validated in the next migration, so adding them does not block the table
# (strong_migrations).
class AddDetailsToSteamApps < ActiveRecord::Migration[8.1]
  DETAILS_EXCLUSIONS = %w[unavailable not_a_game no_title no_vertical_image no_release_date].freeze

  def change
    add_column :steam_apps, :name_en, :string
    add_column :steam_apps, :name_fr, :string
    add_column :steam_apps, :short_description_en, :text
    add_column :steam_apps, :short_description_fr, :text
    add_column :steam_apps, :publishers, :string, array: true
    add_column :steam_apps, :release_on, :date
    add_column :steam_apps, :tag_ids, :integer, array: true
    add_column :steam_apps, :store_url_path, :string
    add_column :steam_apps, :image_url, :string
    add_column :steam_apps, :details, :jsonb
    add_column :steam_apps, :details_run_id, :bigint
    add_column :steam_apps, :details_exclusion, :string

    add_column :steam_apps, :genres, :string, array: true
    add_column :steam_apps, :credit, :text
    add_column :steam_apps, :app_details, :jsonb
    add_column :steam_apps, :genres_run_id, :bigint
    add_column :steam_apps, :genres_exclusion, :string

    add_foreign_key :steam_apps, :steam_import_runs, column: :details_run_id, validate: false
    add_foreign_key :steam_apps, :steam_import_runs, column: :genres_run_id, validate: false
    add_check_constraint :steam_apps, "details_exclusion IS NULL OR details_exclusion IN (#{DETAILS_EXCLUSIONS.map { |code| "'#{code}'" }.join(", ")})",
      name: "steam_apps_details_exclusion_check", validate: false
    add_check_constraint :steam_apps, "genres_exclusion IS NULL OR genres_exclusion = 'unavailable'",
      name: "steam_apps_genres_exclusion_check", validate: false
  end
end
