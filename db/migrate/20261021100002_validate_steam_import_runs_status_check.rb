class ValidateSteamImportRunsStatusCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :steam_import_runs, name: "steam_import_runs_status_check"
  end
end
