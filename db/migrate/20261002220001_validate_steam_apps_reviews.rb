# Validates the foreign key and the check constraint added without validation
# (strong_migrations).
class ValidateSteamAppsReviews < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :steam_apps, column: :reviewed_run_id
    validate_check_constraint :steam_apps, name: "steam_apps_review_exclusion_check"
  end
end
