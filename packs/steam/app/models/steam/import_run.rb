module Steam
  # One run of the Steam import (CAP-2, AD-19): its status, the step it is on,
  # the cursor it resumes from, its counts and its last errors. Started by an
  # administrator; advanced page by page by Steam::ImportStepJob. The database
  # allows one pending or running run at a time. Addressed in URLs by a random
  # token, never by its id (AD-15).
  #
  # Written only through the operations of this pack (AD-3).
  class ImportRun < ApplicationRecord
    self.table_name = "steam_import_runs"

    # The steps of a run, in order. The app list is the only one for now.
    STEPS = %w[app_list].freeze
    # The errors kept on a run, the latest last.
    ERROR_LIMIT = 20

    has_secure_token :token

    enum :status, { pending: "pending", running: "running", completed: "completed", failed: "failed" },
      default: :pending, validate: true

    has_many :apps, class_name: "Steam::App", inverse_of: :import_run, dependent: nil

    scope :active, -> { where(status: %w[pending running]) }
    scope :latest_first, -> { order(created_at: :desc, id: :desc) }

    validates :step, inclusion: { in: STEPS }, allow_nil: true

    # The event stream of a run (AD-10).
    def self.stream_name(id)
      "Steam::ImportRun$#{id}"
    end

    def to_param
      token
    end

    def active?
      pending? || running?
    end

    # The appid the next page of the app list starts after.
    def last_appid
      cursor.fetch("last_appid", 0).to_i
    end

    def apps_listed
      counts.fetch("apps_listed", 0).to_i
    end

    # An error of the run: when it happened and its (key-free) message.
    Error = Data.define(:at, :message)

    # The latest errors, the most recent first.
    def latest_errors(limit = 5)
      error_messages.last(limit).reverse.map do |error|
        at = begin
          Time.iso8601(error["at"].to_s)
        rescue ArgumentError
          nil
        end
        Error.new(at: at, message: error["message"].to_s)
      end
    end
  end
end
