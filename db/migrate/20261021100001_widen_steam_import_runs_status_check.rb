# A run that ends its cards pass waits for promotion (ready), then is promoted.
class WidenSteamImportRunsStatusCheck < ActiveRecord::Migration[8.1]
  OLD = %w[pending running completed failed abandoned].freeze
  NEW = (OLD + %w[ready promoted]).freeze

  def change
    remove_check_constraint :steam_import_runs, equalities(OLD), name: "steam_import_runs_status_check"
    add_check_constraint :steam_import_runs, equalities(NEW), name: "steam_import_runs_status_check", validate: false
  end

  private

  def equalities(statuses)
    statuses.map { |status| "status::text = '#{status}'::text" }.join(" OR ")
  end
end
