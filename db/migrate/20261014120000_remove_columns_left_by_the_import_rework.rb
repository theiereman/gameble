class RemoveColumnsLeftByTheImportRework < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :steam_apps, :steam_import_runs, column: :genres_run_id

    safety_assured do
      remove_check_constraint :steam_apps, "genres_exclusion IS NULL OR genres_exclusion::text = 'unavailable'::text", name: "steam_apps_genres_exclusion_check"
      remove_column :steam_apps, :genres, :string, array: true
      remove_column :steam_apps, :credit, :text
      remove_column :steam_apps, :app_details, :jsonb
      remove_column :steam_apps, :genres_run_id, :bigint
      remove_column :steam_apps, :genres_exclusion, :string
      remove_column :catalog_cards, :credit, :string
    end
  end
end
