module Steam
  class App < ApplicationRecord
    self.table_name = "steam_apps"
    self.ignored_columns += %w[carded_run_id]

    belongs_to :import_run, class_name: "Steam::ImportRun", inverse_of: :apps
    belongs_to :reviewed_run, class_name: "Steam::ImportRun", optional: true

    STORE_URL_BASE = "https://store.steampowered.com/".freeze

    validates :review_exclusion, inclusion: { in: ReviewPolicy::EXCLUSIONS }, allow_nil: true
    validates :details_exclusion, inclusion: { in: DetailsPolicy::EXCLUSIONS }, allow_nil: true

    scope :kept_by, ->(run) { where(reviewed_run_id: run.id, review_exclusion: nil) }

    scope :ready_by, ->(run) { kept_by(run).where(details_run_id: run.id, details_exclusion: nil) }

    def store_url
      STORE_URL_BASE + (store_url_path.present? ? store_url_path.delete_prefix("/") : "app/#{appid}/")
    end

    def developers
      DetailsPolicy.developers(details)
    end

    def franchises
      DetailsPolicy.franchises(details)
    end
  end
end
