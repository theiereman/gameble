# Import hardening before season 1 (story 2.11).
#
# - steam_apps.carded_run_id: the run whose cards step last wrote the app's
#   card, so the end of a cards pass keeps only the cards it wrote in the
#   draft season (Steam::ImportCardsPage, Catalog::PruneDraft).
# - review_exclusion gains malformed_reviews: a review summary whose count
#   or percent Steam answered out of shape (Steam::ReviewPolicy).
# - an import run's status gains abandoned: a failed latest run an
#   administrator gave up on (Steam::AbandonImport).
#
# The foreign key and the check constraints are added without validation
# and validated in the next migration, so adding them does not block the
# tables (strong_migrations). Each replaced check is dropped and added again
# under its name in this migration's transaction.
class HardenTheSteamImport < ActiveRecord::Migration[8.1]
  def change
    add_column :steam_apps, :carded_run_id, :bigint
    add_foreign_key :steam_apps, :steam_import_runs, column: :carded_run_id, validate: false

    remove_check_constraint :steam_apps, "review_exclusion IS NULL OR review_exclusion = 'too_few_reviews' OR review_exclusion = 'unavailable'",
      name: "steam_apps_review_exclusion_check"
    add_check_constraint :steam_apps,
      "review_exclusion IS NULL OR review_exclusion IN ('too_few_reviews', 'unavailable', 'malformed_reviews')",
      name: "steam_apps_review_exclusion_check", validate: false

    remove_check_constraint :steam_import_runs, "status = 'pending' OR status = 'running' OR status = 'completed' OR status = 'failed'",
      name: "steam_import_runs_status_check"
    add_check_constraint :steam_import_runs, "status IN ('pending', 'running', 'completed', 'failed', 'abandoned')",
      name: "steam_import_runs_status_check", validate: false
  end
end
