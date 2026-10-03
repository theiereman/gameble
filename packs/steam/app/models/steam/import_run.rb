module Steam
  # One run of the Steam import (CAP-2, AD-19): its status, the step it is on,
  # the cursor it resumes from, its counts and its last errors. Started by an
  # administrator; advanced page by page by Steam::ImportStepJob. The database
  # allows one pending or running run at a time. Addressed in URLs by a random
  # token, never by its id (AD-15).
  #
  # A failed run is resumed (Steam::ResumeImport) or, while it is the latest
  # and has written no card in its current pass, abandoned
  # (Steam::AbandonImport): an abandoned run is finished for good and blocks
  # no new run; Steam::UnfinishedImportRun skips it.
  #
  # Written only through the operations of this pack (AD-3).
  class ImportRun < ApplicationRecord
    self.table_name = "steam_import_runs"

    # The steps of a run, in order: the app list, the review pass, the tag
    # names, the store details of the kept games, then the cards written into
    # the draft season. (A genres step, on the keyless store API, came between
    # the details and the cards until 2026-10-03.)
    STEPS = %w[app_list reviews tags details cards].freeze
    # The errors kept on a run, the latest last.
    ERROR_LIMIT = 20
    # The length an error message is cut to.
    MESSAGE_LIMIT = 500

    has_secure_token :token

    enum :status, { pending: "pending", running: "running", completed: "completed", failed: "failed", abandoned: "abandoned" },
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

    # The step after `step`, nil after the last one.
    def self.next_step(step)
      index = STEPS.index(step)
      index && STEPS[index + 1]
    end

    # The cursor a step starts from. The cursor names its step, so a job
    # enqueued for an earlier step never matches the run's cursor again.
    def self.cursor_for(step, last_appid: 0)
      { "step" => step, "last_appid" => last_appid }
    end

    # The appid the next page of the current step starts after.
    def last_appid
      cursor.fetch("last_appid", 0).to_i
    end

    # Whether the run is on `step` or went past it.
    def reached?(step)
      current = STEPS.index(self.step)
      target = STEPS.index(step)
      current.present? && target.present? && current >= target
    end

    def apps_listed
      count_of("apps_listed")
    end

    # Apps the review pass looked at, kept and excluded.
    def apps_reviewed
      count_of("apps_reviewed")
    end

    def apps_kept
      count_of("apps_kept")
    end

    def apps_excluded
      count_of("apps_excluded")
    end

    # Tags named by the tags step.
    def tags_named
      count_of("tags_named")
    end

    # Apps the details step looked at, and those it excluded.
    def apps_detailed
      count_of("apps_detailed")
    end

    def apps_excluded_details
      count_of("apps_excluded_details")
    end

    # Cards the cards step wrote into the draft season, and those it refused.
    def cards_written
      count_of("cards_written")
    end

    def cards_refused
      count_of("cards_refused")
    end

    # Cards the end of the cards pass removed from the draft season: those
    # an earlier pass wrote and this one did not.
    def cards_removed
      count_of("cards_removed")
    end

    def count_of(name)
      counts.fetch(name, 0).to_i
    end

    # An error of the run: when it happened and its (key-free) message.
    Error = Data.define(:at, :message)

    # Appends `messages` to the run's errors, each cut to MESSAGE_LIMIT and
    # stamped `at`; only the latest ERROR_LIMIT are kept. Does not save.
    def append_errors(messages, at: Time.current)
      stamp = at.utc.iso8601
      self.error_messages = (error_messages + messages.map { |message| { "at" => stamp, "message" => message.to_s.truncate(MESSAGE_LIMIT) } })
        .last(ERROR_LIMIT)
    end

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
