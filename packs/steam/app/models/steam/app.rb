module Steam
  # A Steam app as GetAppList lists it, games only (AD-4): raw Steam data,
  # one row per appid. Written by Steam::ImportAppListPage with an upsert on
  # appid, so a page imported twice changes nothing twice.
  #
  # Steam::ImportReviewsPage adds the review summary of the latest run that
  # reviewed it (reviewed_run_id) and that run's verdict, review_exclusion:
  # NULL when kept, otherwise one of Steam::ReviewPolicy::EXCLUSIONS.
  class App < ApplicationRecord
    self.table_name = "steam_apps"

    belongs_to :import_run, class_name: "Steam::ImportRun", inverse_of: :apps
    belongs_to :reviewed_run, class_name: "Steam::ImportRun", optional: true

    validates :review_exclusion, inclusion: { in: ReviewPolicy::EXCLUSIONS }, allow_nil: true

    # The apps a run reviewed and kept, for the steps that follow the review
    # pass. An app the run did not list is never reviewed by it, so never kept.
    scope :kept_by, ->(run) { where(reviewed_run_id: run.id, review_exclusion: nil) }
  end
end
