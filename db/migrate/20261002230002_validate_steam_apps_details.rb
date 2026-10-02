# Validates the foreign keys and the check constraints added without
# validation (strong_migrations).
class ValidateSteamAppsDetails < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :steam_apps, column: :details_run_id
    validate_foreign_key :steam_apps, column: :genres_run_id
    validate_check_constraint :steam_apps, name: "steam_apps_details_exclusion_check"
    validate_check_constraint :steam_apps, name: "steam_apps_genres_exclusion_check"
  end
end
