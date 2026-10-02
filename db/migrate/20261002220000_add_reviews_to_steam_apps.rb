# The review pass of the Steam import (CAP-2, epic 2 R3, R5). Each app keeps
# the review summary of the latest run that reviewed it, the raw `reviews`
# object Steam answered, and that run's verdict: NULL when the app is kept,
# too_few_reviews under the review floor, unavailable when the store does
# not answer for it.
#
# The foreign key and the check constraint are added without validation and
# validated in the next migration, so adding them does not block the table
# (strong_migrations).
class AddReviewsToSteamApps < ActiveRecord::Migration[8.1]
  def change
    add_column :steam_apps, :review_count, :integer
    add_column :steam_apps, :review_percent_positive, :integer
    add_column :steam_apps, :reviews, :jsonb
    add_column :steam_apps, :reviewed_run_id, :bigint
    add_column :steam_apps, :review_exclusion, :string

    add_foreign_key :steam_apps, :steam_import_runs, column: :reviewed_run_id, validate: false
    add_check_constraint :steam_apps, "review_exclusion IS NULL OR review_exclusion = 'too_few_reviews' OR review_exclusion = 'unavailable'",
      name: "steam_apps_review_exclusion_check", validate: false
  end
end
