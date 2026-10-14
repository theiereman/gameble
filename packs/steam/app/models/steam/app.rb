module Steam
  # A Steam app as GetAppList lists it, games only (AD-4): raw Steam data,
  # one row per appid. Written by Steam::ImportAppListPage with an upsert on
  # appid, so a page imported twice changes nothing twice.
  #
  # Steam::ImportReviewsPage adds the review summary of the latest run that
  # reviewed it (reviewed_run_id) and that run's verdict, review_exclusion:
  # NULL when kept, otherwise one of Steam::ReviewPolicy::EXCLUSIONS.
  #
  # Steam::ImportDetailsPage adds, for the apps a run kept, their store
  # details in English and French, the run that detailed them
  # (details_run_id) and its verdict, details_exclusion (one of
  # Steam::DetailsPolicy::EXCLUSIONS, NULL when the game can become a card).
  # Steam::ImportCardsPage writes the apps ready by the run into the draft
  # season as cards (Steam::CardMapping), their genres derived from their
  # tags (Catalog::Themes), and marks each app whose card it wrote with the
  # run (carded_run_id); the end of the cards pass keeps only those cards in
  # the draft. A rescore (Steam::RescoreCards) clears the run's marks first.
  class App < ApplicationRecord
    self.table_name = "steam_apps"

    belongs_to :import_run, class_name: "Steam::ImportRun", inverse_of: :apps
    belongs_to :reviewed_run, class_name: "Steam::ImportRun", optional: true
    belongs_to :carded_run, class_name: "Steam::ImportRun", optional: true

    STORE_URL_BASE = "https://store.steampowered.com/".freeze

    validates :review_exclusion, inclusion: { in: ReviewPolicy::EXCLUSIONS }, allow_nil: true
    validates :details_exclusion, inclusion: { in: DetailsPolicy::EXCLUSIONS }, allow_nil: true

    # The apps a run reviewed and kept, for the steps that follow the review
    # pass. An app the run did not list is never reviewed by it, so never kept.
    scope :kept_by, ->(run) { where(reviewed_run_id: run.id, review_exclusion: nil) }

    # The apps a run carried through every step (kept, then detailed without
    # exclusion): each holds what a draft card needs (English title, release
    # date, image and store URL).
    scope :ready_by, ->(run) { kept_by(run).where(details_run_id: run.id, details_exclusion: nil) }

    # The apps whose card the run's current cards pass wrote into the draft.
    scope :carded_by, ->(run) { where(carded_run_id: run.id) }

    # The app's page on the Steam store: its store path, or app/<appid>/
    # when it has none.
    def store_url
      STORE_URL_BASE + (store_url_path.present? ? store_url_path.delete_prefix("/") : "app/#{appid}/")
    end

    # The developers the stored store item names (Steam::DetailsPolicy).
    def developers
      DetailsPolicy.developers(details)
    end

    # The franchises the stored store item names (Steam::DetailsPolicy).
    def franchises
      DetailsPolicy.franchises(details)
    end
  end
end
