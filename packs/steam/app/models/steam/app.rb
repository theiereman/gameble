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
  # Steam::ImportGenresPage then adds their genres and credit (genres_run_id,
  # genres_exclusion). Steam::ImportCardsPage writes the apps ready by the
  # run into the draft season as cards (Steam::CardMapping).
  class App < ApplicationRecord
    self.table_name = "steam_apps"

    belongs_to :import_run, class_name: "Steam::ImportRun", inverse_of: :apps
    belongs_to :reviewed_run, class_name: "Steam::ImportRun", optional: true

    STORE_URL_BASE = "https://store.steampowered.com/".freeze

    validates :review_exclusion, inclusion: { in: ReviewPolicy::EXCLUSIONS }, allow_nil: true
    validates :details_exclusion, inclusion: { in: DetailsPolicy::EXCLUSIONS }, allow_nil: true
    validates :genres_exclusion, inclusion: { in: GenresPolicy::EXCLUSIONS }, allow_nil: true

    # The apps a run reviewed and kept, for the steps that follow the review
    # pass. An app the run did not list is never reviewed by it, so never kept.
    scope :kept_by, ->(run) { where(reviewed_run_id: run.id, review_exclusion: nil) }

    # The apps a run kept and detailed without exclusion, for the genres step.
    scope :detailed_by, ->(run) { kept_by(run).where(details_run_id: run.id, details_exclusion: nil) }

    # The apps a run carried through every step: each holds what a draft card
    # needs (English title, release date, image and store URL).
    scope :ready_by, ->(run) { detailed_by(run).where(genres_run_id: run.id, genres_exclusion: nil) }

    # The app's page on the Steam store: its store path, or app/<appid>/
    # when it has none.
    def store_url
      STORE_URL_BASE + (store_url_path.present? ? store_url_path.delete_prefix("/") : "app/#{appid}/")
    end
  end
end
