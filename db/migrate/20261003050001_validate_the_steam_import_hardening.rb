# Validates the foreign key and the check constraints added without
# validation (strong_migrations).
class ValidateTheSteamImportHardening < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :steam_apps, column: :carded_run_id
    validate_check_constraint :steam_apps, name: "steam_apps_review_exclusion_check"
    validate_check_constraint :steam_import_runs, name: "steam_import_runs_status_check"
  end
end
